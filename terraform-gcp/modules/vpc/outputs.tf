output "vpc_id" {
  description = "ID of the VPC"
  value       = google_compute_network.main.id
}

output "vpc_name" {
  description = "Name of the VPC"
  value       = google_compute_network.main.name
}

output "subnet_ids" {
  description = "IDs of the subnets"
  value       = google_compute_subnetwork.main[*].id
}

output "subnet_names" {
  description = "Names of the subnets"
  value       = google_compute_subnetwork.main[*].name
}

output "pods_cidr_ranges" {
  description = "Pods CIDR ranges"
  value       = var.pods_cidr_ranges
}

output "services_cidr_ranges" {
  description = "Services CIDR ranges"
  value       = var.services_cidr_ranges
}
