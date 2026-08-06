#!/bin/sh
set -eu

# START of maevsi entrypoint script customization
ENVIRONMENT_VARIABLES_PATH="/run/environment-variables"

is_valid_var_name() {
  case "$1" in
    ''|[!a-zA-Z_]*|*[!a-zA-Z0-9_]*) return 1 ;;
    *) return 0 ;;
  esac
}

load_env_file() {
  file="$1"
  name=$(basename "$file")
  is_valid_var_name "$name" || return 0
  value=$(cat "$file")
  export "$name=$value"
}

load_environment_variables() {
  [ -d "$ENVIRONMENT_VARIABLES_PATH" ] || return 0
  set -- "$ENVIRONMENT_VARIABLES_PATH"/*
  [ -e "$1" ] || return 0

  for file in "$ENVIRONMENT_VARIABLES_PATH"/*; do
    [ -f "$file" ] && load_env_file "$file"
  done
}

load_environment_variables
# END of maevsi entrypoint script customization

# DuckDB in this image has no getenv() function, so the R2 values are rendered
# into init.sql. sed treats `&` and `\` specially in replacements, so escape
# them first (R2 keys are hex today, but this keeps arbitrary values safe).
escape_sed_replacement() {
  printf '%s\n' "$1" | sed 's/[&\\]/\\&/g'
}

R2_ACCOUNT_ID="$(escape_sed_replacement "${R2_ACCOUNT_ID}")"
R2_ACCESS_KEY_ID="$(escape_sed_replacement "${R2_ACCESS_KEY_ID}")"
R2_SECRET_ACCESS_KEY="$(escape_sed_replacement "${R2_SECRET_ACCESS_KEY}")"

sed -e "s|__R2_ACCOUNT_ID__|${R2_ACCOUNT_ID}|g" \
    -e "s|__R2_ACCESS_KEY_ID__|${R2_ACCESS_KEY_ID}|g" \
    -e "s|__R2_SECRET_ACCESS_KEY__|${R2_SECRET_ACCESS_KEY}|g" \
    /run/init.sql.template > /tmp/gizmosql-init.sql

exec /opt/gizmosql/scripts/start_gizmosql.sh
