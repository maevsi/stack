#!/usr/bin/env bash
set -euo pipefail

# Generates src/production/production.env from production.env.template and SOPS-encrypted secrets.
# Non-empty values from the template are kept as-is.
# Empty values are filled from secrets.enc.yaml entries with the "env_" prefix.
# SOPS reads the age key from ~/.config/sops/age/keys.txt automatically.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
SECRETS_FILE="$REPO_DIR/secrets.enc.yaml"
TEMPLATE_FILE="$REPO_DIR/src/production/production.env.template"
OUTPUT_FILE="$REPO_DIR/src/production/production.env"

if ! command -v sops &>/dev/null; then
  echo "Error: sops is not installed" >&2
  exit 1
fi

if ! command -v yq &>/dev/null; then
  echo "Error: yq is not installed" >&2
  exit 1
fi

if [ ! -f "$SECRETS_FILE" ]; then
  echo "Error: $SECRETS_FILE not found" >&2
  exit 1
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "Error: $TEMPLATE_FILE not found" >&2
  exit 1
fi

# Decrypt secrets into an associative array using base64 to handle special characters.
declare -A secrets
while IFS=' ' read -r key b64value; do
  secrets["$key"]="$(printf '%s' "$b64value" | base64 -d)"
done < <(sops -d "$SECRETS_FILE" | yq -r 'to_entries[] | select(.key | test("^env_")) | (.key | sub("^env_"; "")) + " " + (.value | @base64)')

# Build production.env from template, filling empty values from secrets.
umask 077
: > "$OUTPUT_FILE"
while IFS= read -r line; do
  # Skip empty lines and comments.
  if [[ -z "$line" || "$line" == \#* ]]; then
    echo "$line" >> "$OUTPUT_FILE"
    continue
  fi

  key="${line%%=*}"
  value="${line#*=}"

  if [[ -z "$value" && -n "${secrets[$key]+x}" ]]; then
    echo "${key}=${secrets[$key]}" >> "$OUTPUT_FILE"
  else
    echo "$line" >> "$OUTPUT_FILE"
  fi
done < "$TEMPLATE_FILE"

echo "Generated $OUTPUT_FILE with $(grep -c '.' "$OUTPUT_FILE") entries."
