output "load_balancer_ip" {
  description = "External IP address of the Load Balancer (API endpoint)"
  value       = google_compute_global_forwarding_rule.vllm_fwd.ip_address
}

output "api_endpoint" {
  description = "vLLM API endpoint URL. Only useful when GPU/vLLM mode is enabled."
  value       = "http://${google_compute_global_forwarding_rule.vllm_fwd.ip_address}/v1"
}

output "instance_name" {
  description = "Name of the Compute Engine instance"
  value       = google_compute_instance.gpu_node.name
}

output "instance_zone" {
  description = "Zone of the Compute Engine instance"
  value       = google_compute_instance.gpu_node.zone
}

output "instance_private_ip" {
  description = "Private IP address of the Compute Engine instance"
  value       = google_compute_instance.gpu_node.network_interface[0].network_ip
}

output "gpu_node_name" {
  description = "Backward-compatible output: name of the Compute Engine instance"
  value       = google_compute_instance.gpu_node.name
}

output "gpu_node_zone" {
  description = "Backward-compatible output: zone of the Compute Engine instance"
  value       = google_compute_instance.gpu_node.zone
}

output "iap_ssh_command" {
  description = "Command to SSH into the Compute Engine instance via IAP"
  value       = "gcloud compute ssh ${google_compute_instance.gpu_node.name} --zone=${google_compute_instance.gpu_node.zone} --tunnel-through-iap --project=${var.project_id}"
}
