terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  name               = var.project_name
  vpc_cidr          = var.vpc_cidr
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnet_cidrs = [
    cidrsubnet(var.vpc_cidr, 8, 1),
    cidrsubnet(var.vpc_cidr, 8, 2)
  ]
  private_subnet_cidrs = [
    cidrsubnet(var.vpc_cidr, 8, 11),
    cidrsubnet(var.vpc_cidr, 8, 12)
  ]

  tags = local.common_tags
}

# EKS Module
module "eks" {
  source = "../../modules/eks"

  cluster_name         = "${var.project_name}-cluster"
  kubernetes_version   = var.kubernetes_version
  subnet_ids          = module.vpc.private_subnet_ids
  node_desired_size   = var.node_desired_size
  node_max_size       = var.node_max_size
  node_min_size       = var.node_min_size
  node_instance_types = var.node_instance_types

  tags = local.common_tags
}

# ECR Repositories
resource "aws_ecr_repository" "user_service" {
  name                 = "${var.project_name}-user-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

resource "aws_ecr_repository" "sleep_service" {
  name                 = "${var.project_name}-sleep-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

# RDS MySQL
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = module.vpc.private_subnet_ids

  tags = local.common_tags
}

resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-rds-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-rds-sg"
  })
}

resource "aws_db_instance" "mysql" {
  identifier = "${var.project_name}-mysql"

  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.db_instance_class

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp2"
  storage_encrypted     = true

  db_name  = "microservices"
  username = var.db_username
  password = var.db_password

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  skip_final_snapshot = true
  deletion_protection = false

  tags = local.common_tags
}

# ElastiCache Redis
resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project_name}-cache-subnet-group"
  subnet_ids = module.vpc.private_subnet_ids
}

resource "aws_security_group" "redis" {
  name_prefix = "${var.project_name}-redis-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-redis-sg"
  })
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "${var.project_name}-redis"
  description                = "Redis cluster for microservices"

  node_type            = var.redis_node_type
  port                 = 6379
  parameter_group_name = "default.redis7"

  num_cache_clusters = 2

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.redis.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  tags = local.common_tags
}

# DocumentDB (MongoDB alternative)
resource "aws_docdb_subnet_group" "main" {
  name       = "${var.project_name}-docdb-subnet-group"
  subnet_ids = module.vpc.private_subnet_ids

  tags = local.common_tags
}

resource "aws_security_group" "docdb" {
  name_prefix = "${var.project_name}-docdb-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-docdb-sg"
  })
}

resource "aws_docdb_cluster" "main" {
  cluster_identifier      = "${var.project_name}-docdb"
  engine                  = "docdb"
  master_username         = var.docdb_username
  master_password         = var.docdb_password
  backup_retention_period = 7
  preferred_backup_window = "07:00-09:00"
  skip_final_snapshot     = true
  deletion_protection     = false

  db_subnet_group_name   = aws_docdb_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.docdb.id]

  tags = local.common_tags
}

resource "aws_docdb_cluster_instance" "main" {
  count              = 2
  identifier         = "${var.project_name}-docdb-${count.index}"
  cluster_identifier = aws_docdb_cluster.main.id
  instance_class     = var.docdb_instance_class
}

# MSK (Kafka)
resource "aws_msk_cluster" "main" {
  cluster_name           = "${var.project_name}-kafka"
  kafka_version          = "2.8.1"
  number_of_broker_nodes = 2

  broker_node_group_info {
    instance_type   = var.kafka_instance_type
    ebs_volume_size = 20
    client_subnets  = module.vpc.private_subnet_ids
    security_groups = [aws_security_group.kafka.id]
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }

  tags = local.common_tags
}

resource "aws_security_group" "kafka" {
  name_prefix = "${var.project_name}-kafka-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-kafka-sg"
  })
}

# Local values
locals {
  common_tags = {
    Project     = var.project_name
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
