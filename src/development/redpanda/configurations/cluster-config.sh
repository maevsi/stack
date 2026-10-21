#!/bin/sh
set -eu

ADMIN_URL="http://redpanda:9644/v1/cluster_config"

# Wait for Redpanda's admin API to be reachable.
echo "Waiting for Redpanda to be ready..."
while ! curl --output /dev/null --silent "$ADMIN_URL"; do
    sleep 5
done

# The continuous balancing features are licensed enterprise features,
# and the cluster runs on the community edition.
# Disabling both keeps the broker on its unlicensed properties.
echo "Disabling the unlicensed enterprise balancing features..."
curl --fail --output /dev/null --silent --show-error \
    -X PUT "$ADMIN_URL" \
    -H "Content-Type: application/json" \
    -d '{"config_properties": {"core_balancing_continuous": false, "partition_auto_balancing_continuous": false}}'

echo "The enterprise balancing features are disabled."
