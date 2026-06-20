# Apigee Provisioning with Terraform (Non-VPC Peering PAYG)

This directory contains the Terraform configuration to provision a Google Cloud Apigee organization (PAYG), environment, environment group, routing (External HTTPS Load Balancer with Private Service Connect), and DNS records.

These files have been generated based on the manual migration guide steps, ensuring a fully automated deployment of your Apigee infrastructure.

## Directory Structure

All resources are split into specialized files following Terraform best practices:

*   [`providers.tf`](file:///usr/local/google/home/sinjoongk/Documents/sinjoonk/apigee-llm-token-quota/terraform/providers.tf): Sets up the Terraform block, required providers (`google` and `google-beta`), and provider blocks.
*   [`variables.tf`](file:///usr/local/google/home/sinjoongk/Documents/sinjoonk/apigee-llm-token-quota/terraform/variables.tf): Declares configurable inputs with default values corresponding to your environment parameters.
*   [`main.tf`](file:///usr/local/google/home/sinjoongk/Documents/sinjoonk/apigee-llm-token-quota/terraform/main.tf): Provisions core services (APIs), KMS keys (for database encryption and instance disk encryption), service agent bindings, Apigee Organization, Instance, Environment, and Environment Group.
*   [`routing.tf`](file:///usr/local/google/home/sinjoongk/Documents/sinjoonk/apigee-llm-token-quota/terraform/routing.tf): Provisions VPC and Subnetwork, regional PSC network endpoint group (NEG), Global IP Address, Google-managed SSL Certificate, Global HTTPS Load Balancer (Backend service, URL Map, Target HTTPS Proxy, Forwarding Rule), and Cloud DNS A record.
*   [`outputs.tf`](file:///usr/local/google/home/sinjoongk/Documents/sinjoonk/apigee-llm-token-quota/terraform/outputs.tf): Exposes essential outputs such as the external IP address of the load balancer and the runtime instance service attachment.

---

## Detailed Resource Map

### 1. APIs & IAM Settings (`main.tf`)
- **APIs enabled**: `apigee.googleapis.com`, `apihub.googleapis.com`, `compute.googleapis.com`, `cloudkms.googleapis.com`.
- **Apigee Service Agent (`google_project_service_identity`)**: Automatically retrieves the Apigee-managed service account identity.
- **KMS Keys**:
  - `apigee-org-key-ring` & `apigee-org-key`: Customer-Managed Encryption Key (CMEK) used to encrypt the runtime organization database.
  - `apigee-instance-key-ring` & `apigee-instance-key`: CMEK used to encrypt runtime instance disks.
- **IAM Policy bindings**: Dynamically grants `roles/cloudkms.cryptoKeyEncrypterDecrypter` to the Apigee service agent for both DB and instance keys (ensured using explicit `depends_on` relationships).
- **Apigee Demo Service Account**:
  - Creates the `apigee-demo` service account.
  - Grants the Apigee service identity `roles/iam.serviceAccountUser` and `roles/iam.serviceAccountTokenCreator` permissions on the service account (allowing Apigee proxies to impersonate it and generate OAuth/ID tokens).
  - Grants the service account `roles/aiplatform.user` permissions on the project to allow successful calls to Vertex AI Gemini/Claude API endpoints.

### 2. Apigee Entities (`main.tf`)
- **Apigee Organization (`google_apigee_organization`)**: Created with `runtime_type = "CLOUD"`, `billing_type = "PAYG"`, and `disable_vpc_peering = true`.
- **Apigee Instance (`google_apigee_instance`)**: Created in the target region using the instance disk key CMEK and `consumer_accept_list` containing your project ID.
- **Apigee Environment (`google_apigee_environment`)**: Configured as type `INTERMEDIATE`.
- **Apigee Env/Instance Attachment (`google_apigee_instance_attachment`)**: Attaches the environment to the runtime instance.
- **Apigee Environment Group (`google_apigee_envgroup`)**: Groups environment endpoints and maps them to the hostname (`apigee.annakie.xyz`).
- **Apigee Envgroup Attachment (`google_apigee_envgroup_attachment`)**: Attaches the environment to the group.

### 3. PSC Routing & External Load Balancer (`routing.tf`)
- **Networking**: Creates `apigee-vpc` and `apigee-subnet` (`10.0.0.0/24`).
- **PSC NEG (`google_compute_region_network_endpoint_group`)**: Establishes Private Service Connect endpoint group pointing directly to the Apigee Instance's `service_attachment`.
- **Global IP (`google_compute_global_address`)**: Reserves a public IPv4 address for your external HTTPS load balancer.
- **HTTPS Load Balancer**:
  - Backend Service (`google_compute_backend_service`) referencing the PSC NEG.
  - URL Map (`google_compute_url_map`) for HTTP routing.
  - Managed SSL Cert (`google_compute_managed_ssl_certificate`) automatically provisioning SSL for the hostname `apigee.annakie.xyz` (named `apigee-cert-v2`, using `create_before_destroy = true` lifecycle rule to prevent resource in use lockups).
  - Target HTTPS Proxy (`google_compute_target_https_proxy`) and Global Forwarding Rule mapping port 443 to the target proxy.
- **Cloud DNS Record (`google_dns_record_set`)**: Automatically registers an `A` record mapping `apigee.annakie.xyz` to the reserved Global IP inside the DNS zone project (`dm-project-391900`).

---

## Instructions to Deploy

### Prerequisites
1. Install [Terraform CLI](https://developer.hashicorp.com/terraform/downloads) (>= 1.3.0).
2. Configure credentials with GCP:
   ```bash
   gcloud auth application-default login
   ```

### Execution Steps
Ensure you are in the `terraform` directory before running:

1. **Initialize Terraform**:
   Downloads the required Google Cloud providers.
   ```bash
   terraform init
   ```

2. **Preview Changes (Dry Run)**:
   Verifies what resources will be created. You can customize variables using a `terraform.tfvars` file or command line arguments.
   ```bash
   terraform plan -var="project_id=YOUR_PROJECT_ID" -var="dns_project_id=YOUR_DNS_PROJECT_ID"
   ```

3. **Apply Configuration**:
   Provision the infrastructure. *Warning: Provisioning Apigee and DNS replication can take up to 15-20 minutes.*
   ```bash
   terraform apply -var="project_id=YOUR_PROJECT_ID" -var="dns_project_id=YOUR_DNS_PROJECT_ID"
   ```
