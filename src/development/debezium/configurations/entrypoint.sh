#!/bin/sh
set -eu

CONNECTOR_NAME="postgres-connector"
DEBEZIUM_URL="http://debezium:8083/connectors"
POSTGRES_DB=$(cat /run/secrets/postgres-db)
POSTGRES_PASSWORD=$(cat /run/secrets/postgres-password)
POSTGRES_USER=$(cat /run/secrets/postgres-user)

# Wait for Debezium to be healthy (REST API ready)
echo "Waiting for Debezium to be ready..."
while ! curl --output /dev/null --silent --show-error "$DEBEZIUM_URL"; do
    sleep 5
done

echo "Debezium is ready. Ensuring PostgreSQL connector is up to date..."

# PUT is idempotent: creates if missing, updates if config changed,
# no-op if unchanged. Preserves WAL offsets across config updates.
#
# The heartbeat writes a logical decoding message into the captured database
# every minute. Without it, the replication slot's confirmed position only
# moves when a captured table changes, while the other databases in the
# cluster keep producing WAL the slot retains, until `max_slot_wal_keep_size`
# invalidates the slot and the connector task fails for good.
curl --fail --output /dev/null --silent --show-error \
    -X PUT "$DEBEZIUM_URL/$CONNECTOR_NAME/config" \
    -H "Content-Type: application/json" \
    -d '{
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.dbname": "'"$POSTGRES_DB"'",
    "database.hostname": "postgres",
    "database.password": "'"$POSTGRES_PASSWORD"'",
    "database.user": "'"$POSTGRES_USER"'",
    "heartbeat.action.query": "SELECT pg_logical_emit_message(false, $$heartbeat$$, now()::text)",
    "heartbeat.interval.ms": "60000",
    "snapshot.mode": "when_needed",
    "plugin.name": "pgoutput",
    "table.include.list": "vibetype.event,vibetype.upload,vibetype_private.notification",
    "topic.prefix" : "vibetype"
}'

echo "PostgreSQL connector '$CONNECTOR_NAME' is up to date."
