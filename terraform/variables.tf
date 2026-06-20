variable "project_id" {
  type        = string
  description = "The ID of the project in which to provision Apigee."
}

variable "dns_project_id" {
  type        = string
  description = "The ID of the project where the Cloud DNS zone exists."
}

variable "region" {
  type        = string
  description = "The region in which to provision the Apigee instance and KMS resources."
  default     = "us-central1"
}

variable "analytics_region" {
  type        = string
  description = "The region for Apigee analytics data storage."
  default     = "us-central1"
}

variable "billing_type" {
  type        = string
  description = "The billing type of the Apigee organization (e.g. PAYG)."
  default     = "PAYG"
}

variable "instance_name" {
  type        = string
  description = "The name of the Apigee runtime instance."
  default     = "demo-instance"
}

variable "environment_name" {
  type        = string
  description = "The name of the Apigee environment."
  default     = "demo-env"
}

variable "environment_type" {
  type        = string
  description = "The type of the Apigee environment."
  default     = "INTERMEDIATE"
}

variable "env_group_name" {
  type        = string
  description = "The name of the Apigee environment group."
  default     = "demo-env-group"
}

variable "env_group_hostname" {
  type        = string
  description = "The hostname for the Apigee environment group."
}

variable "dns_zone_name" {
  type        = string
  description = "The name of the Cloud DNS managed zone for domain verification."
}
