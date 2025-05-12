#!/bin/bash

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

echo "Debezium is ready. Registering PostgreSQL connector..."

# Check if the connector already exists
HTTP_STATUS=$(curl --output /dev/null --silent --show-error -w "%{http_code}" "$DEBEZIUM_URL/$CONNECTOR_NAME")

if [ "$HTTP_STATUS" -eq 200 ]; then
    echo "Connector '$CONNECTOR_NAME' already exists. Skipping registration."
elif [ "$HTTP_STATUS" -eq 404 ]; then
    echo "Connector '$CONNECTOR_NAME' does not exist. Registering..."

    # Register the Debezium PostgreSQL connector
    curl --output /dev/null --silent --show-error \
        -X POST $DEBEZIUM_URL \
        -H "Content-Type: application/json" \
        -d '{
        "name": "'"$CONNECTOR_NAME"'",
        "config": {
            "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
            "database.dbname": "'"$POSTGRES_DB"'",
            "database.hostname": "postgres",
            "database.password": "'"$POSTGRES_PASSWORD"'",
            "database.port": "5432",
            "database.server.name": "postgres",
            "database.user": "'"$POSTGRES_USER"'",
            "plugin.name": "pgoutput",
            "table.include.list": "vibetype.upload,vibetype_private.notification",
            "topic.prefix" : "vibetype"
        }
    }'

    echo "PostgreSQL connector '$CONNECTOR_NAME' registered."
else
    echo "Failed to query Debezium API. HTTP status: $HTTP_STATUS"
    exit 1
fi
