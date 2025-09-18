output "vpc_id" {
  description = "ID of the VPC"
  value       = var.manage_vpc ? module.vpc[0].vpc_id : data.google_compute_network.existing_vpc[0].self_link
}

output "vpc_name" {
  description = "Name of the VPC"
  value       = var.manage_vpc ? module.vpc[0].vpc_name : data.google_compute_network.existing_vpc[0].name
}

output "cluster_name" {
  description = "GKE cluster name"
  value       = module.gke.cluster_name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = module.gke.cluster_endpoint
}

output "cluster_ca_certificate" {
  description = "GKE cluster CA certificate"
  value       = module.gke.cluster_ca_certificate
}

output "cluster_location" {
  description = "GKE cluster location"
  value       = module.gke.cluster_location
}

output "mysql_connection_name" {
  description = "Cloud SQL connection name"
  value       = google_sql_database_instance.mysql.connection_name
}

output "mysql_private_ip" {
  description = "Cloud SQL private IP"
  value       = google_sql_database_instance.mysql.private_ip_address
}

output "redis_host" {
  description = "Redis host"
  value       = var.manage_redis ? google_redis_instance.redis[0].host : data.google_redis_instance.existing[0].host
}

output "redis_port" {
  description = "Redis port"
  value       = var.manage_redis ? google_redis_instance.redis[0].port : data.google_redis_instance.existing[0].port
}

output "pubsub_topics" {
  description = "Pub/Sub topics"
  value = {
    user_events  = var.manage_pubsub ? google_pubsub_topic.user_events[0].name : data.google_pubsub_topic.user_events[0].name
    sleep_events = var.manage_pubsub ? google_pubsub_topic.sleep_events[0].name : data.google_pubsub_topic.sleep_events[0].name
  }
}

output "container_registry_url" {
  description = "Artifact Registry URL (repository: microservices)"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/microservices"
}
