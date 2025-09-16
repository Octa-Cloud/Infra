output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_certificate_authority_data" {
  description = "EKS cluster certificate authority data"
  value       = module.eks.cluster_certificate_authority_data
}

output "ecr_user_service_repository_url" {
  description = "ECR repository URL for user service"
  value       = aws_ecr_repository.user_service.repository_url
}

output "ecr_sleep_service_repository_url" {
  description = "ECR repository URL for sleep service"
  value       = aws_ecr_repository.sleep_service.repository_url
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.mysql.endpoint
}

output "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "docdb_endpoint" {
  description = "DocumentDB endpoint"
  value       = aws_docdb_cluster.main.endpoint
}

output "kafka_bootstrap_brokers" {
  description = "MSK bootstrap brokers"
  value       = aws_msk_cluster.main.bootstrap_brokers
}
