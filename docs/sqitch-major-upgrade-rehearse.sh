#!/bin/sh
# Rehearses docs/sqitch-major-upgrade.md on a throwaway database and checks that every row arrives.
# usage: sqitch-major-upgrade-rehearse.sh <old sqitch tag> <new sqitch tag> [data]
# The data is a whole database dump, either a postgres-backup `.sql.gz` or a `pg_dump -Fc` file, or plain SQL that inserts rows into the old schema.
# Without it the database stays empty.
set -eu

OLD="$1"
NEW="$2"
DATA="${3:-}"
NAME="sqitch-major-upgrade-rehearse"
THIS=$(dirname "$(readlink -f "$0")")
SECRETS=$(mktemp -d)

cleanup() {
  docker rm -f "$NAME" > /dev/null 2>&1 || true
  docker network rm "$NAME" > /dev/null 2>&1 || true
  rm -rf "$SECRETS"
}
trap cleanup EXIT

for service in grafana postgraphile reccoom vibetype zammad; do
  printf '%s' "rehearse_$service" > "$SECRETS/postgres-role-service-$service-username"
  printf '%s' "rehearse_$service" > "$SECRETS/postgres-role-service-$service-password"
done
printf '%s' "db:pg://postgres:postgres@$NAME:5432/vibetype" > "$SECRETS/sqitch-target"
chmod -R a+rX "$SECRETS"

psql() {
  docker exec -i "$NAME" psql -q -v ON_ERROR_STOP=1 -U postgres -d vibetype "$@"
}

sqitch() {
  docker run --rm --network "$NAME" -v "$SECRETS:/run/secrets:ro" "ghcr.io/maevsi/sqitch:$1" sqitch deploy
}

count() {
  psql -At <<EOF
SELECT table_schema || '.' || table_name || '=' || (xpath('/row/c/text()', query_to_xml(format('SELECT count(*) AS c FROM %I.%I', table_schema, table_name), false, true, '')))[1]::text
FROM information_schema.tables
WHERE table_schema IN ('vibetype', 'vibetype_private') AND table_type = 'BASE TABLE'
ORDER BY table_schema, table_name;
EOF
}

docker network create "$NAME" > /dev/null
docker run -d --name "$NAME" --network "$NAME" -e POSTGRES_DB=vibetype -e POSTGRES_PASSWORD=postgres postgis/postgis:18-3.6-alpine > /dev/null
# the image's init phase runs a temporary server on the socket only, so tcp answers once the real one is up
until docker exec "$NAME" pg_isready -q -h 127.0.0.1 -U postgres -d vibetype 2> /dev/null; do sleep 1; done

echo "Deploying $OLD..."
sqitch "$OLD" > /dev/null

# A whole database dump replaces what the old deploy created and only keeps its roles.
# Grants to the production service roles, which have other names here, fail and are skipped.
case "$DATA" in
  "") ;;
  *.sql) psql < "$DATA" > /dev/null ;;
  *.sql.gz)
    psql -c 'DROP SCHEMA vibetype, vibetype_private, sqitch CASCADE' 2> /dev/null
    gunzip -c "$DATA" | docker exec -i "$NAME" psql -q -U postgres -d vibetype > /dev/null 2>&1 || true
    ;;
  *)
    psql -c 'DROP SCHEMA vibetype, vibetype_private, sqitch CASCADE' 2> /dev/null
    docker exec -i "$NAME" pg_restore --no-owner --no-privileges -U postgres -d vibetype < "$DATA" > /dev/null 2>&1 || true
    ;;
esac

BEFORE=$(count)

psql <<'EOF'
ALTER SCHEMA vibetype RENAME TO vibetype_old;
ALTER SCHEMA vibetype_private RENAME TO vibetype_private_old;
ALTER SCHEMA sqitch RENAME TO sqitch_old;
EOF

echo "Deploying $NEW..."
sqitch "$NEW" > /dev/null

echo "Copying the data..."
psql < "$THIS/sqitch-major-upgrade.sql" 2>&1 | sed -n 's/^.*NOTICE:  //p' | grep -v ': 0 rows$'

# tables the new major added are expected to differ, they did not exist before
AFTER=$(count)
MISSING=$(printf '%s\n' "$BEFORE" | while IFS='=' read -r table rows; do
  printf '%s\n' "$AFTER" | grep -qx "$table=$rows" || echo "$table: $rows before, $(printf '%s\n' "$AFTER" | sed -n "s/^$table=//p") after"
done)

if [ -n "$MISSING" ]; then
  echo "Row counts differ:"
  echo "$MISSING"
  exit 1
fi

echo "Every row arrived."
