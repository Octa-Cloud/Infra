terraform {
  required_version = ">= 1.0"                      # Terraform 최소 버전
  required_providers {                              # 사용할 프로바이더 명시
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"                           # google provider 버전
    }
  }
}

provider "google" {
  project = var.project_id                          # 기본 프로젝트 ID
  region  = var.region                              # 기본 리전
}

# Data sources
data "google_client_config" "default" {}            # 현재 gcloud 클라이언트 정보

# VPC Module
module "vpc" {                                      # VPC 모듈 호출
  count  = var.manage_vpc ? 1 : 0
  source = "../../modules/vpc"

  name                   = var.project_name         # VPC 이름 프리픽스
  region                 = var.region               # 리전
  availability_zones     = var.availability_zones   # AZ 목록
  subnet_cidrs           = var.subnet_cidrs         # 서브넷 CIDR
  pods_cidr_ranges       = var.pods_cidr_ranges     # Pods 세컨더리 범위
  services_cidr_ranges   = var.services_cidr_ranges # Services 세컨더리 범위
}

# Use data sources when manage_vpc=false
data "google_compute_network" "existing_vpc" {
  count   = var.manage_vpc ? 0 : 1
  name    = var.project_name
  project = var.project_id
}

############################################
# Private Service Connect for Cloud SQL
# - VPC에 Service Networking 피어링을 생성해
#   Cloud SQL Private IP를 사용할 수 있게 합니다
############################################
resource "google_compute_global_address" "private_service_range" {
  name          = "${var.project_name}-ps-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.manage_vpc ? module.vpc[0].vpc_id : data.google_compute_network.existing_vpc[0].self_link
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = var.manage_vpc ? module.vpc[0].vpc_id : data.google_compute_network.existing_vpc[0].self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_range.name]
}

# GKE Module
module "gke" {                                      # GKE 모듈 호출
  source = "../../modules/gke"

  project_id      = var.project_id
  cluster_name    = "${var.project_name}-cluster"  # 클러스터 이름
  region          = var.region
  network         = var.manage_vpc ? module.vpc[0].vpc_name : data.google_compute_network.existing_vpc[0].name
  subnetwork      = var.manage_vpc ? module.vpc[0].subnet_names[0] : "${var.project_name}-subnet-1"
  enable_autopilot = var.enable_autopilot           # Autopilot 여부
}

# Cloud SQL (MySQL)
resource "google_sql_database_instance" "mysql" {  # Cloud SQL MySQL 인스턴스
  name             = "${var.project_name}-mysql"
  database_version = "MYSQL_8_0"
  region           = var.region
  project          = var.project_id

  settings {
    tier                 = var.db_tier              # 머신 티어(사양)
    disk_size            = var.db_disk_size         # 디스크 크기(GB)
    disk_type            = var.db_disk_type         # 디스크 유형(PD_SSD)
    disk_autoresize      = true                     # 자동 확장 허용
    disk_autoresize_limit = 100                     # 자동 확장 상한

    ip_configuration {                              # 네트워크 설정
      ipv4_enabled    = false                       # 공인 IP 비활성화
      private_network = var.manage_vpc ? module.vpc[0].vpc_id : data.google_compute_network.existing_vpc[0].self_link
      ssl_mode        = "ENCRYPTED_ONLY"           # require_ssl 대체
    }

    backup_configuration {                           # 백업/복구 설정(MySQL)
      enabled                = true
      start_time             = "03:00"
      binary_log_enabled     = true                  # MySQL PITR용, binlog 활성화
      transaction_log_retention_days = 7
      backup_retention_settings {
        retained_backups = 7
        retention_unit   = "COUNT"
      }
    }

    maintenance_window {                             # 유지보수 창
      day          = 7                               # 일(일요일)
      hour         = 3                               # 03:00
      update_track = "stable"
    }
  }

  deletion_protection = false
  depends_on = [
    google_service_networking_connection.private_vpc_connection
  ]
}

resource "google_sql_database" "user_db" {        # user-service 용 DB 스키마
  name     = "user_db"
  instance = google_sql_database_instance.mysql.name
  project  = var.project_id
}

resource "google_sql_database" "sleep_db" {       # sleep-service 용 DB 스키마
  name     = "sleep_db"
  instance = google_sql_database_instance.mysql.name
  project  = var.project_id
}

resource "google_sql_user" "mysql_user" {        # MySQL 사용자 계정
  name     = var.db_username
  instance = google_sql_database_instance.mysql.name
  password = var.db_password
  project  = var.project_id
}

# Memorystore (Redis)
resource "google_redis_instance" "redis" {        # Memorystore Redis
  count          = var.manage_redis ? 1 : 0
  name           = "${var.project_name}-redis"
  tier           = "STANDARD_HA"
  memory_size_gb = var.redis_memory_size
  region         = var.region
  project        = var.project_id

  location_id             = var.availability_zones[0]
  alternative_location_id = var.availability_zones[1]

  redis_version     = "REDIS_7_0"                 # 버전
  display_name      = "Redis for microservices"
  reserved_ip_range = "10.0.0.0/29"

  auth_enabled = true
}

data "google_redis_instance" "existing" {
  count    = var.manage_redis ? 0 : 1
  name     = "${var.project_name}-redis"
  region   = var.region
  project  = var.project_id
}

# Firestore (MongoDB 대체)
resource "google_firestore_database" "firestore" { # Firestore (DocumentDB 대체)
  count       = var.manage_firestore ? 1 : 0
  project     = var.project_id
  name        = "(default)"          # database_id 역할, provider v5에서는 name 사용
  location_id = var.region
  type        = "FIRESTORE_NATIVE"
}

# Pub/Sub (Kafka 대체)
resource "google_pubsub_topic" "user_events" {    # Pub/Sub Topic (user)
  count   = var.manage_pubsub ? 1 : 0
  name    = "user-events"
  project = var.project_id
}

resource "google_pubsub_topic" "sleep_events" {   # Pub/Sub Topic (sleep)
  count   = var.manage_pubsub ? 1 : 0
  name    = "sleep-events"
  project = var.project_id
}

data "google_pubsub_topic" "user_events" {
  count   = var.manage_pubsub ? 0 : 1
  name    = "user-events"
  project = var.project_id
}

data "google_pubsub_topic" "sleep_events" {
  count   = var.manage_pubsub ? 0 : 1
  name    = "sleep-events"
  project = var.project_id
}

resource "google_pubsub_subscription" "user_events_sub" { # 사용자 이벤트 서브스크립션
  name  = "user-events-subscription"
  topic = var.manage_pubsub ? google_pubsub_topic.user_events[0].name : data.google_pubsub_topic.user_events[0].name
  project = var.project_id

  ack_deadline_seconds = 20
}

resource "google_pubsub_subscription" "sleep_events_sub" { # 수면 이벤트 서브스크립션
  name  = "sleep-events-subscription"
  topic = var.manage_pubsub ? google_pubsub_topic.sleep_events[0].name : data.google_pubsub_topic.sleep_events[0].name
  project = var.project_id

  ack_deadline_seconds = 20
}

# Container Registry
# Artifact Registry를 사용하므로 (구) Container Registry 리소스는 생성하지 않습니다.

# Service Account for GKE
resource "google_service_account" "gke_sa" {      # GKE용 서비스 계정
  count        = var.manage_service_account ? 1 : 0
  account_id   = "${var.project_name}-gke-sa"
  display_name = "GKE Service Account"
  project      = var.project_id
}

resource "google_project_iam_member" "gke_sa_roles" { # SA에 필요한 역할 바인딩
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
  member  = var.manage_service_account ? "serviceAccount:${google_service_account.gke_sa[0].email}" : "serviceAccount:${var.project_name}-gke-sa@${var.project_id}.iam.gserviceaccount.com"
}

# Workload Identity
resource "google_service_account_iam_member" "workload_identity" { # Workload Identity 바인딩
  count              = var.manage_service_account ? 1 : 0
  service_account_id = google_service_account.gke_sa[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[default/gke-sa]"
}
