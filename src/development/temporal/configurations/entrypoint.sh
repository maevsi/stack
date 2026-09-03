#!/bin/sh
set -eu

# The auto-setup image has no support for Docker's `_FILE`-suffixed secret convention, so read the mounted secret files ourselves and hand the plain values to the image's own entrypoint.
export POSTGRES_USER="$(cat /run/secrets/postgres-role-service-temporal-username)"
export POSTGRES_PWD="$(cat /run/secrets/postgres-role-service-temporal-password)"

exec /etc/temporal/entrypoint.sh autosetup
