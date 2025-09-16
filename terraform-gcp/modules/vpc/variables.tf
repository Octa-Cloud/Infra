variable "name" {
  description = "Name of the VPC"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "subnet_cidrs" {
  description = "CIDR blocks for subnets"
  type        = list(string)
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
