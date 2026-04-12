variable "age_secret_key" {
  description = "age private key for SOPS decryption (placed on manager node)."
  sensitive   = true
  type        = string
}

variable "hcloud_token" {
  description = "Hetzner Cloud API token."
  sensitive   = true
  type        = string
}

variable "location" {
  default     = "nbg1"
  description = "Hetzner Cloud location."
  type        = string
}

variable "server_type_manager" {
  default     = "cx23"
  description = "Hetzner Cloud server type for the manager node."
  type        = string
}

variable "server_type_worker" {
  default     = "cx33"
  description = "Hetzner Cloud server type for the worker node."
  type        = string
}

variable "ssh_public_key_path" {
  default     = "~/.ssh/id_ed25519.pub"
  description = "Path to the SSH public key to inject into servers."
  type        = string
}

variable "ssh_source_ips" {
  description = "CIDRs allowed to SSH into the servers. Must be set explicitly (e.g. your operator IP or VPN range)."
  type        = list(string)

  validation {
    condition     = length(var.ssh_source_ips) > 0
    error_message = "ssh_source_ips must not be empty. Specify at least one CIDR (e.g. your operator IP)."
  }
}

variable "stack_repo_url" {
  default     = "https://github.com/maevsi/stack.git"
  description = "Git URL of the stack repository to clone on the manager node."
  type        = string
}
