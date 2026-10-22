#!/bin/sh
set -eu

BROKERS="redpanda:9092"

# Wait for the broker to accept connections.
echo "Waiting for Redpanda to be ready..."
until rpk cluster config get core_balancing_continuous --api-urls "$BROKERS" >/dev/null 2>&1; do
    sleep 5
done

# The continuous balancing features are licensed enterprise features,
# and the cluster runs on the community edition.
# Disabling both keeps the broker on its unlicensed properties.
echo "Disabling the unlicensed enterprise balancing features..."
rpk cluster config set core_balancing_continuous false --api-urls "$BROKERS"
rpk cluster config set partition_auto_balancing_continuous false --api-urls "$BROKERS"

echo "The enterprise balancing features are disabled."
