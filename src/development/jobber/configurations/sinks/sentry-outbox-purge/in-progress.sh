#!/bin/sh

curl "${SENTRY_CRONS_OUTBOX_PURGE}?status=in_progress"
