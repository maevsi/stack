#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../../../.."

if ! command -v sops &>/dev/null; then
  echo "Error: sops is not installed" >&2
  exit 1
fi

if ! command -v yq &>/dev/null; then
  echo "Error: yq is not installed" >&2
  exit 1
fi

SECRETS_FILE="${1:-secrets.enc.yaml}"

if [[ ! -f "$SECRETS_FILE" ]]; then
  echo "Error: $SECRETS_FILE not found" >&2
  exit 1
fi

echo "Decrypting $SECRETS_FILE and creating Docker secrets..."

sops --decrypt "$SECRETS_FILE" | yq -r 'del(.sops) | to_entries[] | .key + " " + (.value | @base64)' | \
  while IFS=' ' read -r name b64value; do
    if docker secret inspect "$name" >/dev/null 2>&1; then
      echo "  exists: $name"
    else
      printf '%s' "$b64value" | base64 -d | docker secret create "$name" -
      echo "  created: $name"
    fi
  done

echo "Done."
