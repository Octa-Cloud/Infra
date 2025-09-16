terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Data sources
data "google_client_config" "default" {}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  name               = var.project_name
  region            = var.region
  availability_zones = var.availability_zones
  subnet_cidrs      = var.subnet_cidrs
  pods_cidr_ranges  = var.pods_cidr_ranges
  services_cidr_ranges = var.services_cidr_ranges
}

# GKE Module
module "gke" {
  source = "../../modules/gke"

  project_id    = var.project_id
  cluster_name  = "${var.project_name}-cluster"
  region        = var.region
  network       = module.vpc.vpc_name
  subnetwork    = module.vpc.subnet_names[0]
  enable_autopilot = var.enable_autopilot

  depends_on = [module.vpc]
}

# Cloud SQL (MySQL)
resource "google_sql_database_instance" "mysql" {
  name             = "${var.project_name}-mysql"
  database_version = "MYSQL_8_0"
  region           = var.region
  project          = var.project_id

  settings {
    tier = var.db_tier
    disk_size = var.db_disk_size
    disk_type = var.db_disk_type
    disk_autoresize = true
    disk_autoresize_limit = 100

    ip_configuration {
      ipv4_enabled    = false
      private_network = module.vpc.vpc_id
      require_ssl     = true
    }

    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7
      backup_retention_settings {
        retained_backups = 7
        retention_unit   = "COUNT"
      }
    }

    maintenance_window {
      day          = 7
      hour         = 3
      update_track = "stable"
    }
  }

  deletion_protection = false
}

resource "google_sql_database" "user_db" {
  name     = "user_db"
  instance = google_sql_database_instance.mysql.name
  project  = var.project_id
}

resource "google_sql_database" "sleep_db" {
  name     = "sleep_db"
  instance = google_sql_database_instance.mysql.name
  project  = var.project_id
}

resource "google_sql_user" "mysql_user" {
  name     = var.db_username
  instance = google_sql_database_instance.mysql.name
  password = var.db_password
  project  = var.project_id
}

# Memorystore (Redis)
resource "google_redis_instance" "redis" {
  name           = "${var.project_name}-redis"
  tier           = "STANDARD_HA"
  memory_size_gb = var.redis_memory_size
  region         = var.region
  project        = var.project_id

  location_id             = var.availability_zones[0]
  alternative_location_id = var.availability_zones[1]

  redis_version     = "REDIS_7_0"
  display_name      = "Redis for microservices"
  reserved_ip_range = "10.0.0.0/29"

  auth_enabled = true
}

# Firestore (MongoDB 대체)
resource "google_firestore_database" "firestore" {
  project     = var.project_id
  database_id = "(default)"
  location_id = var.region
  type        = "FIRESTORE_NATIVE"
}

# Pub/Sub (Kafka 대체)
resource "google_pubsub_topic" "user_events" {
  name    = "user-events"
  project = var.project_id
}

resource "google_pubsub_topic" "sleep_events" {
  name    = "sleep-events"
  project = var.project_id
}

resource "google_pubsub_subscription" "user_events_sub" {
  name  = "user-events-subscription"
  topic = google_pubsub_topic.user_events.name
  project = var.project_id

  ack_deadline_seconds = 20
}

resource "google_pubsub_subscription" "sleep_events_sub" {
  name  = "sleep-events-subscription"
  topic = google_pubsub_topic.sleep_events.name
  project = var.project_id

  ack_deadline_seconds = 20
}

# Container Registry
resource "google_container_registry" "registry" {
  project = var.project_id
  location = var.region
}

# Service Account for GKE
resource "google_service_account" "gke_sa" {
  account_id   = "${var.project_name}-gke-sa"
  display_name = "GKE Service Account"
  project      = var.project_id
}

resource "google_project_iam_member" "gke_sa_roles" {
  for_each = toset([
    "roles/container.nodeServiceAccount",
    "roles/storage.objectViewer",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/cloudtrace.agent"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_sa.email}"
}

# Workload Identity
resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = google_service_account.gke_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[default/gke-sa]"
}
