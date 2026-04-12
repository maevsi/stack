#!/usr/bin/env bash
set -euo pipefail

# Decrypts SOPS-encrypted variables and runs Terraform.
# SOPS reads the age key from ~/.config/sops/age/keys.txt automatically.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TFVARS_ENC="$SCRIPT_DIR/terraform.tfvars.enc.yaml"
TFVARS_JSON="$SCRIPT_DIR/terraform.tfvars.json"

cleanup() {
  rm -f "$TFVARS_JSON"
}
trap cleanup EXIT

# Only decrypt and pass -var-file for subcommands that support it.
case "${1:-}" in
  plan|apply|destroy|import|refresh|console)
    if [ ! -f "$TFVARS_ENC" ]; then
      echo "Error: $TFVARS_ENC not found" >&2
      exit 1
    fi

    if ! command -v sops &>/dev/null; then
      echo "Error: sops is not installed" >&2
      exit 1
    fi

    if ! command -v yq &>/dev/null; then
      echo "Error: yq is not installed" >&2
      exit 1
    fi

    # Decrypt SOPS YAML to JSON tfvars, stripping the sops metadata key.
    # Create with restrictive permissions to protect decrypted secrets.
    umask 077
    sops -d "$TFVARS_ENC" | yq -o=json 'del(.sops)' > "$TFVARS_JSON"

    terraform -chdir="$SCRIPT_DIR" "$@" -var-file="$TFVARS_JSON"
    ;;
  *)
    terraform -chdir="$SCRIPT_DIR" "$@"
    ;;
esac
