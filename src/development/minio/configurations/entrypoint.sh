#!/bin/sh

# create dirs for required buckets
mkdir -p /data/vibetype-backup
mkdir -p /data/vibetype-images

# delegate to real entrypoint
# shellcheck disable=SC1091
. /usr/bin/docker-entrypoint.sh