#!/bin/sh
set -eu

CONNECTOR_NAME="postgres-connector"
DEBEZIUM_URL="http://debezium:8083/connectors"
POSTGRES_DB=$(cat /run/secrets/postgres_db)
POSTGRES_PASSWORD=$(cat /run/secrets/postgres_password)
POSTGRES_USER=$(cat /run/secrets/postgres_user)

# Wait for Debezium to be healthy (REST API ready)
echo "Waiting for Debezium to be ready..."
while ! curl --output /dev/null --silent --show-error "$DEBEZIUM_URL"; do
    sleep 5
done

echo "Debezium is ready. Ensuring PostgreSQL connector is up to date..."

# PUT is idempotent: creates if missing, updates if config changed,
# no-op if unchanged. Preserves WAL offsets across config updates.
curl --fail --output /dev/null --silent --show-error \
    -X PUT "$DEBEZIUM_URL/$CONNECTOR_NAME/config" \
    -H "Content-Type: application/json" \
    -d '{
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.dbname": "'"$POSTGRES_DB"'",
    "database.hostname": "postgres",
    "database.password": "'"$POSTGRES_PASSWORD"'",
    "database.user": "'"$POSTGRES_USER"'",
    "plugin.name": "pgoutput",
    "table.include.list": "vibetype.event,vibetype.upload,vibetype_private.notification",
    "topic.prefix" : "vibetype"
}'

echo "PostgreSQL connector '$CONNECTOR_NAME' is up to date."
