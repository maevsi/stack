#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../../../.."

BACKUP_DIR="${1:?Usage: $0 <backup-directory>}"

if [[ ! -d "$BACKUP_DIR" ]]; then
  echo "Error: $BACKUP_DIR does not exist" >&2
  exit 1
fi

echo "Restoring databases from $BACKUP_DIR..."

# Find the node running a service task and execute a command there.
# If the task runs locally, uses docker exec directly.
# If the task runs on another node, SSHes to that node first.
run_on_task_node() {
  local service_name="$1"
  shift

  local node
  node=$(docker service ps --filter desired-state=running --format '{{.Node}}' "vibetype_${service_name}" 2>/dev/null | head -1)

  if [[ -z "$node" ]]; then
    echo "  Error: service vibetype_${service_name} has no running tasks" >&2
    return 1
  fi

  local container
  if [[ "$node" == "$(hostname)" ]]; then
    container=$(docker ps -q -f "label=com.docker.swarm.service.name=vibetype_${service_name}" 2>/dev/null | head -1)
    if [[ -n "$container" ]]; then
      docker exec -i "$container" "$@"
      return 0
    fi
  else
    local node_addr
    node_addr=$(docker node inspect --format '{{.Status.Addr}}' "$node")
    ssh -o BatchMode=yes "root@${node_addr}" "docker exec -i \$(docker ps -q -f label=com.docker.swarm.service.name=vibetype_${service_name} | head -1) $(printf '%q ' "$@")"
    return
  fi

  echo "  Error: container for vibetype_${service_name} not found on $node" >&2
  return 1
}

failed=0

# Main PostgreSQL
if [[ -f "$BACKUP_DIR/postgres.sql" ]]; then
  echo "  Restoring main PostgreSQL..."
  if run_on_task_node postgres psql -v ON_ERROR_STOP=1 -U postgres < "$BACKUP_DIR/postgres.sql"; then
    echo "  Restored: postgres.sql"
  else
    echo "  Error: main PostgreSQL restore failed" >&2
    failed=1
  fi
else
  echo "  Skipping: postgres.sql not found in backup"
fi

# Reccoom PostgreSQL
if [[ -f "$BACKUP_DIR/reccoom-postgres.sql" ]]; then
  echo "  Restoring Reccoom PostgreSQL..."
  if run_on_task_node reccoom_postgres psql -v ON_ERROR_STOP=1 -U postgres < "$BACKUP_DIR/reccoom-postgres.sql"; then
    echo "  Restored: reccoom-postgres.sql"
  else
    echo "  Error: Reccoom PostgreSQL restore failed" >&2
    failed=1
  fi
else
  echo "  Skipping: reccoom-postgres.sql not found in backup"
fi

echo "Restore complete."
exit "$failed"
