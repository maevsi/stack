#!/bin/sh
set -eu

ADMIN_URL="http://redpanda:9644/v1/cluster_config"

# Wait for Redpanda's admin API to be reachable.
echo "Waiting for Redpanda to be ready..."
while ! curl --fail --silent --output /dev/null "$ADMIN_URL"; do
    sleep 5
done

# The continuous balancing features are licensed enterprise features,
# and the cluster runs on the community edition.
# Disabling both keeps the broker on its unlicensed properties.
echo "Disabling the unlicensed enterprise balancing features..."

# The property names changed across broker versions, so the script
# disables whichever of them the running broker still knows.
set_property() {
    if ! curl --fail --silent --output /dev/null "$ADMIN_URL/$1"; then
        return 0
    fi
    curl --fail --silent --output /dev/null --show-error \
        -X PUT "$ADMIN_URL" \
        -H "Content-Type: application/json" \
        -d "{\"config_properties\": [{\"name\": \"$1\", \"value\": $2}]}"
}

set_property core_balancing_continuous false
set_property partition_auto_balancing_continuous false
set_property partition_autobalancing_mode '"node_add"'

echo "The enterprise balancing features are disabled."
