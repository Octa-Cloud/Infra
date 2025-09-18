variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "microservices"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "asia-northeast3"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["asia-northeast3-a", "asia-northeast3-b"]
}

variable "subnet_cidrs" {
  description = "CIDR blocks for subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "pods_cidr_ranges" {
  description = "CIDR ranges for pods"
  type        = list(string)
  default     = ["10.1.0.0/16", "10.2.0.0/16"]
}

variable "services_cidr_ranges" {
  description = "CIDR ranges for services"
  type        = list(string)
  default     = ["10.3.0.0/16", "10.4.0.0/16"]
}

variable "enable_autopilot" {
  description = "Enable GKE Autopilot"
  type        = bool
  default     = true
}

variable "db_tier" {
  description = "Cloud SQL instance tier"
  type        = string
  default     = "db-f1-micro"
}

variable "db_disk_size" {
  description = "Cloud SQL disk size in GB"
  type        = number
  default     = 20
}

variable "db_disk_type" {
  description = "Cloud SQL disk type"
  type        = string
  default     = "PD_SSD"
}

variable "db_username" {
  description = "Cloud SQL username"
  type        = string
  default     = "root"
}

variable "db_password" {
  description = "Cloud SQL password"
  type        = string
  sensitive   = true
}

variable "redis_memory_size" {
  description = "Redis memory size in GB"
  type        = number
  default     = 1
}

# Management toggles: when false, use data sources instead of creating resources
variable "manage_vpc" {
  description = "Whether to create/manage VPC with Terraform"
  type        = bool
  default     = false
}

variable "manage_redis" {
  description = "Whether to create/manage Redis with Terraform"
  type        = bool
  default     = false
}

variable "manage_pubsub" {
  description = "Whether to create/manage Pub/Sub topics with Terraform"
  type        = bool
  default     = false
}

variable "manage_service_account" {
  description = "Whether to create/manage GKE service account with Terraform"
  type        = bool
  default     = false
}

variable "manage_firestore" {
  description = "Whether to create/manage Firestore database with Terraform"
  type        = bool
  default     = false
}
