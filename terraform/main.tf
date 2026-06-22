resource "google_project_service" "apis" {
  for_each = toset([
    "apigee.googleapis.com",
    "apihub.googleapis.com",
    "compute.googleapis.com",
    "cloudkms.googleapis.com"
  ])
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

resource "google_project_service_identity" "apigee_sa" {
  provider = google-beta
  project  = var.project_id
  service  = "apigee.googleapis.com"

  depends_on = [google_project_service.apis]
}

# KMS Key Ring and Key for Apigee Org DB Encryption
resource "google_kms_key_ring" "apigee_db_keyring" {
  name     = "apigee-org-key-ring"
  location = var.region
  project  = var.project_id

  depends_on = [google_project_service.apis]
}

resource "google_kms_crypto_key" "apigee_db_key" {
  name     = "apigee-org-key"
  key_ring = google_kms_key_ring.apigee_db_keyring.id
  purpose  = "ENCRYPT_DECRYPT"
}

resource "google_kms_crypto_key_iam_member" "apigee_sa_db_key_binding" {
  crypto_key_id = google_kms_crypto_key.apigee_db_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_project_service_identity.apigee_sa.email}"

  depends_on = [google_project_service_identity.apigee_sa]
}

# KMS Key Ring and Key for Apigee Instance Disk Encryption
resource "google_kms_key_ring" "apigee_instance_keyring" {
  name     = "apigee-instance-key-ring"
  location = var.region
  project  = var.project_id

  depends_on = [google_project_service.apis]
}

resource "google_kms_crypto_key" "apigee_instance_key" {
  name     = "apigee-instance-key"
  key_ring = google_kms_key_ring.apigee_instance_keyring.id
  purpose  = "ENCRYPT_DECRYPT"
}

resource "google_kms_crypto_key_iam_member" "apigee_sa_instance_key_binding" {
  crypto_key_id = google_kms_crypto_key.apigee_instance_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_project_service_identity.apigee_sa.email}"

  depends_on = [google_project_service_identity.apigee_sa]
}

# Service Account and IAM user role binding for Apigee Demo
resource "google_service_account" "apigee_demo" {
  account_id   = "apigee-demo"
  display_name = "Apigee Demo Service Account"
  project      = var.project_id

  depends_on = [google_project_service.apis]
}

resource "google_service_account_iam_member" "apigee_sa_user" {
  service_account_id = google_service_account.apigee_demo.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_project_service_identity.apigee_sa.email}"
}

resource "google_service_account_iam_member" "apigee_sa_token_creator" {
  service_account_id = google_service_account.apigee_demo.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_project_service_identity.apigee_sa.email}"
}

# Apigee Organization Creation (VPC Peering Disabled for PAYG)
resource "google_apigee_organization" "apigee_org" {
  analytics_region                     = var.analytics_region
  project_id                           = var.project_id
  runtime_type                         = "CLOUD"
  billing_type                         = var.billing_type
  disable_vpc_peering                  = true
  runtime_database_encryption_key_name = google_kms_crypto_key.apigee_db_key.id

  depends_on = [
    google_kms_crypto_key_iam_member.apigee_sa_db_key_binding
  ]
}

# Apigee Instance Creation
resource "google_apigee_instance" "apigee_instance" {
  name                     = var.instance_name
  location                 = var.region
  org_id                   = google_apigee_organization.apigee_org.id
  disk_encryption_key_name = google_kms_crypto_key.apigee_instance_key.id
  consumer_accept_list     = [var.project_id]

  depends_on = [
    google_kms_crypto_key_iam_member.apigee_sa_instance_key_binding
  ]
}

# Apigee Environment Creation
resource "google_apigee_environment" "apigee_env" {
  name         = var.environment_name
  org_id       = google_apigee_organization.apigee_org.id
  type         = var.environment_type
  display_name = var.environment_name
  description  = "Apigee environment for ${var.environment_name}"
}

# Attach Environment to Instance
resource "google_apigee_instance_attachment" "apigee_env_attachment" {
  instance_id = google_apigee_instance.apigee_instance.id
  environment = google_apigee_environment.apigee_env.name
}

# Apigee Environment Group Creation
resource "google_apigee_envgroup" "apigee_env_group" {
  name      = var.env_group_name
  org_id    = google_apigee_organization.apigee_org.id
  hostnames = [var.env_group_hostname]
}

# Attach Environment to Environment Group
resource "google_apigee_envgroup_attachment" "apigee_envgroup_attachment" {
  envgroup_id = google_apigee_envgroup.apigee_env_group.id
  environment = google_apigee_environment.apigee_env.name
}

# Grant Vertex AI User role to the Apigee Demo Service Account
resource "google_project_iam_member" "apigee_sa_vertex_user" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.apigee_demo.email}"
}

# Grant Logging Log Writer role to the Apigee Demo Service Account
resource "google_project_iam_member" "apigee_sa_logging_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.apigee_demo.email}"
}

