#!/bin/sh
set -u

GIZMOSQL_PASSWORD="$(cat /run/secrets/gizmosql-password)"
export GIZMOSQL_PASSWORD

run() {
  gizmosql_client --host gizmosql --username gizmosql --quiet "$@" >/dev/null
}

# Ingestion and erasure every minute, compaction, snapshot expiry and file cleanup every hour.
minute=0
while :; do
  run --file /run/maintenance.sql
  if [ $((minute % 60)) -eq 0 ]; then
    run --command 'CHECKPOINT lakehouse'
  fi
  minute=$((minute + 1))
  sleep 60
done
