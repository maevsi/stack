output "manager_ipv6" {
  description = "Public IPv6 address of the manager node."
  value       = hcloud_server.manager.ipv6_address
}

output "manager_private_ip" {
  description = "Private IP of the manager node."
  value       = local.manager_private_ip
}

output "worker_ipv6" {
  description = "Public IPv6 address of the worker node."
  value       = hcloud_server.worker.ipv6_address
}

output "worker_private_ip" {
  description = "Private IP of the worker node."
  value       = local.worker_private_ip
}
