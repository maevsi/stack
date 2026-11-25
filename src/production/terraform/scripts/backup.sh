#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../../../.."

BACKUP_DIR="${1:-./backups/$(date +%Y%m%d-%H%M%S)}"
umask 077
mkdir -p "$BACKUP_DIR"

echo "Backing up databases to $BACKUP_DIR..."

# Find the node running a service task and execute a command there.
# If the task runs locally, uses docker exec directly.
# If the task runs on another node, SSHes to that node first.
run_on_task_node() {
  local service_name="$1"
  shift

  local node
  node=$(docker service ps --filter desired-state=running --format '{{.Node}}' "vibetype_${service_name}" 2>/dev/null | head -1)

  if [[ -z "$node" ]]; then
    echo "  Warning: service vibetype_${service_name} has no running tasks"
    return 1
  fi

  local container
  if [[ "$node" == "$(hostname)" ]]; then
    container=$(docker ps -q -f "label=com.docker.swarm.service.name=vibetype_${service_name}" 2>/dev/null | head -1)
    if [[ -n "$container" ]]; then
      docker exec "$container" "$@"
      return 0
    fi
  else
    local node_addr
    node_addr=$(docker node inspect --format '{{.Status.Addr}}' "$node")
    ssh -o BatchMode=yes "root@${node_addr}" "docker exec \$(docker ps -q -f label=com.docker.swarm.service.name=vibetype_${service_name} | head -1) $(printf '%q ' "$@")"
    return
  fi

  echo "  Warning: container for vibetype_${service_name} not found on $node"
  return 1
}

failed=0

# Main PostgreSQL
echo "  Dumping main PostgreSQL..."
if run_on_task_node postgres pg_dumpall -U postgres > "$BACKUP_DIR/postgres.sql"; then
  echo "  Saved: $BACKUP_DIR/postgres.sql"
else
  echo "  Warning: main PostgreSQL backup failed"
  failed=1
fi

# Reccoom PostgreSQL
echo "  Dumping Reccoom PostgreSQL..."
if run_on_task_node reccoom_postgres pg_dumpall -U postgres > "$BACKUP_DIR/reccoom-postgres.sql"; then
  echo "  Saved: $BACKUP_DIR/reccoom-postgres.sql"
else
  echo "  Warning: Reccoom PostgreSQL backup failed"
  failed=1
fi

echo "Backup complete: $BACKUP_DIR"
ls -lh "$BACKUP_DIR"
exit "$failed"
