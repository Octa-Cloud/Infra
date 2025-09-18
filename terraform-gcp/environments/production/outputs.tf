output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_name" {
  description = "Name of the VPC"
  value       = module.vpc.vpc_name
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
  value       = google_redis_instance.redis.host
}

output "redis_port" {
  description = "Redis port"
  value       = google_redis_instance.redis.port
}

output "pubsub_topics" {
  description = "Pub/Sub topics"
  value = {
    user_events  = google_pubsub_topic.user_events.name
    sleep_events = google_pubsub_topic.sleep_events.name
  }
}

output "container_registry_url" {
  description = "Artifact Registry URL (repository: microservices)"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/microservices"
}
