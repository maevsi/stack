#!/bin/sh
set -eu

BROKERS="redpanda:9092"

# Wait for the broker to accept connections.
echo "Waiting for Redpanda to be ready..."
until rpk topic list --api-urls "$BROKERS" >/dev/null 2>&1; do
    sleep 5
done

# The continuous balancing features are licensed enterprise features,
# and the cluster runs on the community edition.
# Disabling both keeps the broker on its unlicensed properties.
echo "Disabling the unlicensed enterprise balancing features..."

# The property names changed across broker versions, so the script
# disables whichever of the legacy names the running broker still knows.
for property in core_balancing_continuous partition_auto_balancing_continuous; do
    if rpk cluster config get "$property" --api-urls "$BROKERS" >/dev/null 2>&1; then
        rpk cluster config set "$property" false --api-urls "$BROKERS"
    fi
done

# Current versions replaced the legacy partition flag with a mode property;
# node_add is the unlicensed behaviour and keeps balancing on node additions.
if rpk cluster config get partition_autobalancing_mode --api-urls "$BROKERS" >/dev/null 2>&1; then
    rpk cluster config set partition_autobalancing_mode node_add --api-urls "$BROKERS"
fi

echo "The enterprise balancing features are disabled."
