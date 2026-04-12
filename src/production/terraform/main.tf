provider "hcloud" {
  token = var.hcloud_token
}

locals {
  manager_private_ip = "10.0.1.1"
  worker_private_ip  = "10.0.1.2"
}

resource "hcloud_ssh_key" "default" {
  name       = "vibetype"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

resource "hcloud_network" "swarm" {
  ip_range = "10.0.0.0/16"
  name     = "vibetype-swarm"
}

resource "hcloud_network_subnet" "swarm" {
  ip_range     = "10.0.1.0/24"
  network_id   = hcloud_network.swarm.id
  network_zone = "eu-central"
  type         = "cloud"
}

resource "hcloud_firewall" "swarm" {
  name = "vibetype-swarm"

  # SSH (operator access)
  rule {
    description = "SSH"
    direction   = "in"
    port        = "22"
    protocol    = "tcp"
    source_ips  = var.ssh_source_ips
  }

  # SSH (inter-node, for backup/restore scripts)
  rule {
    description = "SSH (private network)"
    direction   = "in"
    port        = "22"
    protocol    = "tcp"
    source_ips  = ["10.0.1.0/24"]
  }

  # HTTP
  rule {
    description = "HTTP"
    direction   = "in"
    port        = "80"
    protocol    = "tcp"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  # HTTPS
  rule {
    description = "HTTPS"
    direction   = "in"
    port        = "443"
    protocol    = "tcp"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  # Docker Swarm management (private network)
  rule {
    description = "Swarm management"
    direction   = "in"
    port        = "2377"
    protocol    = "tcp"
    source_ips  = ["10.0.1.0/24"]
  }

  # Docker Swarm node communication (private network)
  rule {
    description = "Swarm TCP communication"
    direction   = "in"
    port        = "7946"
    protocol    = "tcp"
    source_ips  = ["10.0.1.0/24"]
  }

  rule {
    description = "Swarm UDP communication"
    direction   = "in"
    port        = "7946"
    protocol    = "udp"
    source_ips  = ["10.0.1.0/24"]
  }

  # Docker Swarm overlay network (private network)
  rule {
    description = "Swarm overlay network"
    direction   = "in"
    port        = "4789"
    protocol    = "udp"
    source_ips  = ["10.0.1.0/24"]
  }
}

resource "hcloud_server" "manager" {
  firewall_ids = [hcloud_firewall.swarm.id]
  image        = "docker-ce"
  location     = var.location
  name         = "vibetype-manager"
  server_type  = var.server_type_manager
  ssh_keys     = [hcloud_ssh_key.default.id]

  public_net {
    ipv4_enabled = false
    ipv6_enabled = true
  }

  user_data = templatefile("${path.module}/cloud-init/manager.yaml", {
    private_ip     = local.manager_private_ip
    stack_repo_url = var.stack_repo_url
  })

  network {
    network_id = hcloud_network.swarm.id
    ip         = local.manager_private_ip
  }

  depends_on = [hcloud_network_subnet.swarm]
}

resource "hcloud_server" "worker" {
  firewall_ids = [hcloud_firewall.swarm.id]
  image        = "docker-ce"
  location     = var.location
  name         = "vibetype-worker"
  server_type  = var.server_type_worker
  ssh_keys     = [hcloud_ssh_key.default.id]

  public_net {
    ipv4_enabled = false
    ipv6_enabled = true
  }

  user_data = templatefile("${path.module}/cloud-init/worker.yaml", {})

  network {
    network_id = hcloud_network.swarm.id
    ip         = local.worker_private_ip
  }

  depends_on = [hcloud_network_subnet.swarm]
}

resource "terraform_data" "swarm_join" {
  depends_on = [hcloud_server.manager, hcloud_server.worker]

  triggers_replace = [
    hcloud_server.manager.id,
    hcloud_server.worker.id,
  ]

  # Wait for cloud-init and save the join token to a file.
  provisioner "remote-exec" {
    connection {
      agent = true
      host  = hcloud_server.manager.ipv6_address
      type  = "ssh"
      user  = "root"
    }

    inline = [
      "cloud-init status --wait",
      "docker swarm join-token worker -q > /root/swarm-worker-token.txt",
    ]
  }

  # Join the worker to the Swarm using the operator's SSH agent.
  provisioner "remote-exec" {
    connection {
      agent = true
      host  = hcloud_server.worker.ipv6_address
      type  = "ssh"
      user  = "root"
    }

    inline = [
      "cloud-init status --wait",
    ]
  }

  # The worker's token must be fetched from the manager first.
  # Note: ssh-keyscan uses TOFU (trust on first use). For newly provisioned servers
  # this is acceptable since the IPs are known and the firewall restricts SSH access.
  # For higher assurance, pin expected host key fingerprints via a secure channel.
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      KNOWN_HOSTS=$(mktemp)
      trap 'rm -f "$KNOWN_HOSTS"' EXIT
      ssh-keyscan -H ${hcloud_server.manager.ipv6_address} >> "$KNOWN_HOSTS" 2>/dev/null
      ssh-keyscan -H ${hcloud_server.worker.ipv6_address} >> "$KNOWN_HOSTS" 2>/dev/null
      if [ ! -s "$KNOWN_HOSTS" ]; then
        echo "Error: ssh-keyscan returned no host keys" >&2
        exit 1
      fi
      TOKEN=$(ssh -o UserKnownHostsFile="$KNOWN_HOSTS" root@${hcloud_server.manager.ipv6_address} cat /root/swarm-worker-token.txt | tr -d '[:space:]')
      ssh -o UserKnownHostsFile="$KNOWN_HOSTS" root@${hcloud_server.worker.ipv6_address} "docker swarm join --token '$TOKEN' ${local.manager_private_ip}:2377"
    EOT
  }

  # Label the worker node.
  provisioner "remote-exec" {
    connection {
      agent = true
      host  = hcloud_server.manager.ipv6_address
      type  = "ssh"
      user  = "root"
    }

    inline = [
      "docker node update --label-add role=worker vibetype-worker",
    ]
  }
}

resource "terraform_data" "deploy" {
  depends_on = [terraform_data.swarm_join]

  triggers_replace = [
    hcloud_server.manager.id,
    var.stack_repo_url,
  ]

  connection {
    agent = true
    host  = hcloud_server.manager.ipv6_address
    type  = "ssh"
    user  = "root"
  }

  # Copy the age private key to the manager (avoids embedding it in user_data/state).
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /root/.config/sops/age",
    ]
  }

  provisioner "local-exec" {
    environment = {
      AGE_KEY_B64  = base64encode(var.age_secret_key)
      MANAGER_HOST = hcloud_server.manager.ipv6_address
    }

    command = <<-EOT
      set -euo pipefail
      KNOWN_HOSTS=$(mktemp)
      trap 'rm -f "$KNOWN_HOSTS"' EXIT
      ssh-keyscan -H "$MANAGER_HOST" >> "$KNOWN_HOSTS" 2>/dev/null
      printf '%s' "$AGE_KEY_B64" | ssh -o UserKnownHostsFile="$KNOWN_HOSTS" "root@$MANAGER_HOST" "base64 -d > /root/.config/sops/age/keys.txt && chmod 600 /root/.config/sops/age/keys.txt"
    EOT
  }

  # Create Docker secrets, generate environment, and deploy.
  provisioner "remote-exec" {
    inline = [
      "bash /opt/vibetype/src/production/terraform/scripts/create-secrets.sh",
      "bash /opt/vibetype/src/production/terraform/scripts/generate-env.sh",
      "cd /opt/vibetype && dargstack deploy -p latest --offline",
    ]
  }
}
