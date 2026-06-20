# VPC Network for Apigee
resource "google_compute_network" "apigee_vpc" {
  name                    = "apigee-vpc"
  auto_create_subnetworks = false
  project                 = var.project_id

  depends_on = [google_project_service.apis]
}

# Subnet inside VPC
resource "google_compute_subnetwork" "apigee_subnet" {
  name          = "apigee-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.apigee_vpc.id
  project       = var.project_id
}

# Region Network Endpoint Group (PSC NEG) pointing to Apigee service attachment
resource "google_compute_region_network_endpoint_group" "apigee_neg" {
  name                  = "apigee-neg"
  region                = var.region
  network               = google_compute_network.apigee_vpc.id
  subnetwork            = google_compute_subnetwork.apigee_subnet.id
  network_endpoint_type = "PRIVATE_SERVICE_CONNECT"
  psc_target_service    = google_apigee_instance.apigee_instance.service_attachment
  project               = var.project_id
}

# Reserve a Global External IP Address for Load Balancer
resource "google_compute_global_address" "apigee_ip" {
  name         = "apigee-ip"
  ip_version   = "IPV4"
  address_type = "EXTERNAL"
  project      = var.project_id

  depends_on = [google_project_service.apis]
}

# Load Balancer Backend Service
resource "google_compute_backend_service" "apigee_bs" {
  name                  = "apigee-bs"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTPS"
  project               = var.project_id
  timeout_sec           = 300

  backend {
    group = google_compute_region_network_endpoint_group.apigee_neg.id
  }
}

# Load Balancer URL Map
resource "google_compute_url_map" "apigee_url_map" {
  name            = "apigee-url-map"
  default_service = google_compute_backend_service.apigee_bs.id
  project         = var.project_id
}

# Google-managed SSL Certificate
resource "google_compute_managed_ssl_certificate" "apigee_cert" {
  name    = "apigee-cert-v2"
  project = var.project_id

  managed {
    domains = [var.env_group_hostname]
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [google_project_service.apis]
}

# Target HTTPS Proxy
resource "google_compute_target_https_proxy" "apigee_target_proxy" {
  name             = "apigee-target-proxy"
  url_map          = google_compute_url_map.apigee_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.apigee_cert.id]
  project          = var.project_id
}

# Global Forwarding Rule for HTTPS (Port 443)
resource "google_compute_global_forwarding_rule" "apigee_forwarding_rule" {
  name                  = "apigee-forwarding-rule"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  network_tier          = "PREMIUM"
  ip_address            = google_compute_global_address.apigee_ip.address
  target                = google_compute_target_https_proxy.apigee_target_proxy.id
  port_range            = "443"
  project               = var.project_id
}

# Cloud DNS A Record for Domain Verification (created in dns_project_id)
resource "google_dns_record_set" "apigee_dns_record" {
  name         = "${var.env_group_hostname}."
  type         = "A"
  ttl          = 300
  managed_zone = var.dns_zone_name
  rrdatas      = [google_compute_global_address.apigee_ip.address]
  project      = var.dns_project_id
}
