# Secrets Management

Secrets are managed using [SOPS](https://github.com/getsops/sops) with [age](https://github.com/FiloSottile/age) encryption. Encrypted secrets are committed to the repository. Only the age private key must be kept secret.

## How It Works

1. All Docker Swarm secrets are stored as key-value pairs in `secrets.enc.yaml` (encrypted, safe to commit publicly)
2. `.sops.yaml` in the repository root specifies the age public key used for encryption (must be updated with your real public key before encrypting)
3. The `scripts/create-secrets.sh` script decrypts the file and feeds each entry into `docker secret create`
4. The age private key is copied to the manager node by a Terraform provisioner at provisioning time (never stored in Terraform state)

> **Important:** Before first provisioning, both `.sops.yaml` (with the real age public key) and `secrets.enc.yaml` (created and encrypted) must be committed to the repository. The Terraform `deploy` provisioner runs `create-secrets.sh` after cloud-init completes, which will fail if `secrets.enc.yaml` is missing from the cloned repo.

## Tools

| Tool | Purpose | Install |
|---|---|---|
| [age](https://github.com/FiloSottile/age) | Encryption keypair | `apt install age` |
| [SOPS](https://github.com/getsops/sops) | Encrypt/decrypt YAML values | [GitHub releases](https://github.com/getsops/sops/releases) |
| [yq](https://github.com/mikefarah/yq) | YAML processing | [GitHub releases](https://github.com/mikefarah/yq/releases) |

## age Keypair

The keypair is generated with:

```sh
age-keygen -o ~/.config/sops/age/keys.txt
```

This outputs a public key (e.g. `age1abc...`) and stores the private key in the file. The public key is referenced in `.sops.yaml`:

```yaml
creation_rules:
  - path_regex: secrets\.enc\.yaml$
    age: "age1abc..."
```

## Encrypted Secrets File

`secrets.enc.yaml` contains all Docker Swarm secrets. Keys are readable, values are encrypted. This file must be created and encrypted before first deployment:

```sh
# Create from the provided template, fill in values, then encrypt
cp secrets.example.yaml secrets.enc.yaml
# Edit secrets.enc.yaml with your real values
sops -e -i secrets.enc.yaml
```

```yaml
postgres_password: ENC[AES256_GCM,data:abc123...,iv:...,tag:...]
grafana_admin_password: ENC[AES256_GCM,data:def456...,iv:...,tag:...]
```

The full list of secret keys matches the `secrets:` section in `src/development/stack.yml`:

```yaml
elasticsearch-keystore_password: "<value>"
elasticsearch-password: "<value>"
grafana_admin_email: "<value>"
grafana_admin_password: "<value>"
grafana_admin_user: "<value>"
grafana_discord_webhook: "<value>"
jobber_aliases: "<value>"
jobber_aws-bucket: "<value>"
jobber_aws-configuration: "<multiline value>"
jobber_aws-credentials: "<multiline value>"
jobber_msmtprc: "<multiline value>"
portainer_admin-password: "<value>"
postgraphile_connection: "<value>"
postgraphile_jwt-secret: "<multiline value>"
postgraphile_owner-connection: "<value>"
postgres-backup_db: "<value>"
postgres_db: "<value>"
postgres_password: "<value>"
postgres_role_service_grafana_password: "<value>"
postgres_role_service_grafana_username: "<value>"
postgres_role_service_postgraphile_password: "<value>"
postgres_role_service_postgraphile_username: "<value>"
postgres_role_service_vibetype_password: "<value>"
postgres_role_service_vibetype_username: "<value>"
postgres_role_service_zammad_password: "<value>"
postgres_role_service_zammad_username: "<value>"
postgres_user: "<value>"
reccoom_ingest-api-key: "<value>"
reccoom_openai-api-key: "<value>"
sqitch_target: "<value>"
traefik_cf-dns-api-token: "<value>"
traefik_cf-zone-api-token: "<value>"
tusd_aws: "<multiline value>"
vibetype_api-notification-secret: "<value>"
vibetype_aws-credentials: "<multiline value>"
vibetype_firebase-service-account-credentials: "<multiline value>"
vibetype_monday: "<multiline value>"
vibetype_openai-api-key: "<value>"
vibetype_turnstile-key: "<value>"
```

## Editing Secrets

```sh
sops secrets.enc.yaml
```

Opens the decrypted file in `$EDITOR`. Re-encrypts automatically on save and close.

## Creating Docker Swarm Secrets

```sh
bash src/production/terraform/scripts/create-secrets.sh
```

Decrypts `secrets.enc.yaml` and runs `docker secret create` for each entry. Existing secrets are skipped.

## Rotating a Secret

Docker Swarm secrets are immutable. To rotate a secret, all services using it must be scaled down first:

```sh
# 1. Edit the secret value
sops secrets.enc.yaml

# 2. Scale down services that use the secret
docker service scale vibetype_postgres=0

# 3. Remove and recreate the secret
docker secret rm postgres_password
bash src/production/terraform/scripts/create-secrets.sh

# 4. Scale services back up
docker service scale vibetype_postgres=1
```

Alternatively, redeploy the entire stack (which removes and recreates all services):

```sh
docker stack rm vibetype
# Wait for all services to fully stop
bash src/production/terraform/scripts/create-secrets.sh
dargstack deploy -p <tag>
```

## Where the Age Key Lives

| Location | Purpose |
|---|---|
| `~/.config/sops/age/keys.txt` | Developer machine |
| `/root/.config/sops/age/keys.txt` | Manager node (copied by Terraform `deploy` provisioner) |
| `terraform.tfvars.enc.yaml` (`age_secret_key`) | Passed to Terraform, decrypted by `tf.sh` wrapper |

## Security Notes

- `terraform.tfvars.json` (decrypted) and `keys.txt` must never be committed (both are git-ignored)
- The age private key is copied to the manager via SSH stdin and never stored in Terraform state
- `.sops.yaml` contains only the public key and is safe to commit
- `secrets.enc.yaml` is encrypted and safe to commit to a public repository
- Only the age private key needs to be kept secret
