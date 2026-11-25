# Provisioning

The infrastructure runs on [Hetzner Cloud](https://console.hetzner.cloud/) as a two-node Docker Swarm cluster, managed by [Terraform](https://developer.hashicorp.com/terraform/install).

## Architecture

| Node | Hostname | Private IP | Role |
|---|---|---|---|
| Manager | `vibetype-manager` | 10.0.1.1 | Swarm manager, monitoring, secrets |
| Worker | `vibetype-worker` | 10.0.1.2 | Application services |

Both nodes use the Hetzner `docker-ce` image in the nbg1 location and are connected via a private network (`vibetype-swarm`, 10.0.0.0/16, subnet 10.0.1.0/24). The manager uses a CX23 (2 vCPU, 4 GB) and the worker uses a CX33 (4 vCPU, 8 GB) to handle the application workload.

> **TODO:** After validating real-world memory usage via cAdvisor + Grafana, add Docker resource limits/reservations for memory-hungry worker services (PostgreSQL, Redpanda, Zammad, Debezium, Memcached, Redis). Elasticsearch already has limits (2560M limit, 1536M reservation).

## Terraform Resources

| Resource | Name | Purpose |
|---|---|---|
| SSH key | `vibetype` | Injected from local `~/.ssh/id_ed25519.pub` |
| Network | `vibetype-swarm` | Private network (10.0.0.0/16) |
| Subnet | `vibetype-swarm` | 10.0.1.0/24 in eu-central |
| Firewall | `vibetype-swarm` | SSH, HTTP, HTTPS (public), Swarm ports 2377/7946/4789 (private) |
| Server | `vibetype-manager` | Swarm manager node |
| Server | `vibetype-worker` | Swarm worker node |
| terraform_data | `swarm_join` | Orchestrates Swarm join: waits for cloud-init, joins worker, labels nodes |
| terraform_data | `deploy` | Copies age key, creates secrets, generates env, deploys stack |

## Terraform Variables

| Variable | Description | Default |
|---|---|---|
| `age_secret_key` | Age private key for SOPS decryption (sensitive) | required |
| `hcloud_token` | Hetzner Cloud API token (sensitive) | required |
| `location` | Hetzner datacenter | `nbg1` |
| `server_type_manager` | Server type for the manager node | `cx23` |
| `server_type_worker` | Server type for the worker node | `cx33` |
| `ssh_public_key_path` | Path to SSH public key | `~/.ssh/id_ed25519.pub` |
| `ssh_source_ips` | CIDRs allowed to SSH into servers | required |
| `stack_repo_url` | Git URL of the stack repository | `https://github.com/maevsi/stack.git` |

These are stored encrypted in `terraform.tfvars.enc.yaml` using SOPS and age. The `tf.sh` wrapper decrypts them before running Terraform. SOPS reads the age key from `~/.config/sops/age/keys.txt` automatically.

> **Note:** `terraform.tfvars.enc.yaml` ships as a plaintext template with placeholder values. Before first use, fill in the real values and encrypt it with `sops -e -i terraform.tfvars.enc.yaml`.

## Running Terraform

Before running Terraform for the first time, ensure:
- `.sops.yaml` contains your real age public key (not the placeholder)
- `secrets.enc.yaml` has been created and encrypted (see [Secrets Management](secrets.md))
- `terraform.tfvars.enc.yaml` has been encrypted with `sops -e -i`

```sh
./tf.sh init
./tf.sh plan
./tf.sh apply
```

The wrapper decrypts `terraform.tfvars.enc.yaml` into a temporary `terraform.tfvars.json` file, runs the requested Terraform command, and cleans up the decrypted file.

## Automated Provisioning Flow

Running `terraform apply` triggers the following:

### Manager node (cloud-init)

1. Installs `sops`, `yq`, and `dargstack` (with checksum verification)
2. Initializes Docker Swarm on the private network
3. Labels itself with `role=manager`
4. Clones the stack repository to `/opt/vibetype`

### Worker node (Terraform provisioner)

1. Waits for manager and worker cloud-init to complete
2. Populates a known_hosts file via `ssh-keyscan` for both nodes
3. Fetches the Swarm join token from the manager
4. Joins the worker to the Swarm
5. Labels the worker with `role=worker`

### Deployment (Terraform provisioner)

1. Copies the age private key to `/root/.config/sops/age/keys.txt` on the manager (via SSH, never stored in Terraform state)
2. Runs `scripts/create-secrets.sh` to create all Docker Swarm secrets from `secrets.enc.yaml`
3. Runs `scripts/generate-env.sh` to generate `src/production/production.env` from the template and encrypted secrets
4. Deploys the full stack using `dargstack deploy -p latest --offline`

## Placement Constraints

| Placement | Services |
|---|---|
| `node.labels.role == manager` | adminer, cloudflared, grafana, prometheus |
| `node.labels.role == worker` | All application services (debezium, elasticsearch, jobber, postgraphile, postgres, reccoom, redis, vibetype, zammad, etc.) |
| `mode: global` (all nodes) | cadvisor, node-exporter, portainer-agent, traefik |

## Production Environment

The production environment is built from two layers, following the dargstack convention:

- `src/development/stack.env`: Shared configuration values (committed to Git)
- `src/production/production.env.template`: Production-specific variables template (committed to Git)
- `src/production/production.env`: Generated from the template with secrets filled in by `scripts/generate-env.sh` (not committed)

dargstack merges `development/stack.env` + `production/production.env` into `production/stack.env` at deploy time. For zero-touch and CD deployments, both files are sourced directly.

Non-sensitive variables in `production.env.template` (pre-filled):

| Variable | Description |
|---|---|
| `STACK_DOMAIN` | Production domain |
| `TRAEFIK_ACME_PROVIDER` | DNS provider for ACME |

Sensitive variables filled from `secrets.enc.yaml` (prefixed with `env_`):

| Variable | Description |
|---|---|
| `CLOUDFLARED_TUNNEL_TOKEN` | Cloudflare tunnel token |
| `SENTRY_CRONS` | Sentry cron monitoring URL |
| `TRAEFIK_ACME_EMAIL` | Email for Let's Encrypt certificates |

## Deploying the Stack

The stack is deployed automatically during provisioning and on every GitHub release via the CD workflow (`.github/workflows/cd.yml`).

The CD workflow:
1. Triggers on every published GitHub release
2. Checks for major version upgrades (blocks deployment if the major version differs from `DEPLOYED_MAJOR_VERSION` repository variable)
3. SSHs to the manager node, checks out the release tag, creates any new secrets (existing secrets are skipped), regenerates the environment file, and redeploys the stack using dargstack

Required GitHub secrets:
- `MANAGER_IPV6`: IPv6 address of the manager node
- `SSH_PRIVATE_KEY`: SSH private key for root access

Required GitHub repository variable:
- `DEPLOYED_MAJOR_VERSION`: Current deployed major version (e.g. `1`). Update manually after a major version upgrade.

For manual redeployment:

```sh
ssh root@<manager-ip>
cd /opt/vibetype
bash src/production/terraform/scripts/create-secrets.sh
bash src/production/terraform/scripts/generate-env.sh
dargstack deploy -p <tag>
```

## Verifying Deployment

```sh
# List all services and their status
docker stack services vibetype

# Check service logs
docker service logs vibetype_traefik
docker service logs vibetype_grafana

# Verify node placement
docker service ps vibetype_prometheus --format '{{.Node}}'  # Should show vibetype-manager
docker service ps vibetype_vibetype --format '{{.Node}}'    # Should show vibetype-worker
```

## Backup and Restore

### Backup

```sh
bash src/production/terraform/scripts/backup.sh [output-directory]
```

Creates SQL dumps of main PostgreSQL and Reccoom PostgreSQL. Defaults to `./backups/<timestamp>/`. The script automatically discovers which node runs each database service and SSHes to the correct node if the task is remote.

### Restore

```sh
bash src/production/terraform/scripts/restore.sh <backup-directory>
```

Restores SQL dumps from the specified directory into running PostgreSQL containers. Like backup, the script discovers the correct node for each database service automatically. Uses `psql -v ON_ERROR_STOP=1` to fail on the first SQL error.

## Teardown

```sh
# Backup databases first (runs from manager, SSHes to worker node for DB containers)
ssh root@<manager-ip> "cd /opt/vibetype && bash src/production/terraform/scripts/backup.sh"
scp -r root@<manager-ip>:/opt/vibetype/backups/ ./backups/

# Destroy infrastructure
./tf.sh destroy
```

## Re-provisioning

To rebuild the infrastructure from scratch:

1. Run `./tf.sh destroy`
2. Run `./tf.sh apply` (cloud-init sets up Swarm and tools; Terraform provisioners handle secrets, environment, and deployment)
3. Run `src/production/terraform/scripts/restore.sh` to restore database backups (if applicable)
