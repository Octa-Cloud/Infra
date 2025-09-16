output "cluster_id" {
  description = "GKE cluster ID"
  value       = google_container_cluster.main.id
}

output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.main.name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  description = "GKE cluster CA certificate"
  value       = google_container_cluster.main.master_auth[0].cluster_ca_certificate
}

output "cluster_location" {
  description = "GKE cluster location"
  value       = google_container_cluster.main.location
}

output "cluster_region" {
  description = "GKE cluster region"
  value       = var.region
}

output "cluster_zones" {
  description = "GKE cluster zones"
  value       = google_container_cluster.main.node_locations
}
