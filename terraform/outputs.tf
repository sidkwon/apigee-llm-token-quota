output "load_balancer_ip" {
  description = "The reserved global IP address of the Apigee External Load Balancer."
  value       = google_compute_global_address.apigee_ip.address
}

output "apigee_service_attachment" {
  description = "The service attachment URI of the Apigee runtime instance."
  value       = google_apigee_instance.apigee_instance.service_attachment
}

output "apigee_env_group_hostname" {
  description = "The configured hostname for the Apigee environment group."
  value       = var.env_group_hostname
}
