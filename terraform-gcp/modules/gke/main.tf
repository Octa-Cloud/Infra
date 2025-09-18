# GKE Cluster
# - Autopilot/Standard 모두 지원하도록 옵션을 노출합니다.
# - remove_default_node_pool=true 로 한 뒤 별도 node pool을 관리하거나
#   Autopilot 모드일 때는 node pool을 만들지 않습니다.
resource "google_container_cluster" "main" {
  name     = var.cluster_name   # 클러스터 이름
  location = var.region         # 리전(Regional) 또는 존(Zonal) 위치 값
  project  = var.project_id     # GCP 프로젝트 ID

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  # Autopilot 모드일 때는 기본 노드풀 관련 속성 사용 불가
  remove_default_node_pool = var.enable_autopilot ? null : true
  initial_node_count       = var.enable_autopilot ? null : 1

  network    = var.network      # 연결할 VPC 네트워크 이름
  subnetwork = var.subnetwork   # 연결할 서브넷 이름

  # Enable Autopilot
  enable_autopilot = var.enable_autopilot # true면 Autopilot 클러스터

  # Enable Workload Identity
  workload_identity_config {            # Workload Identity: GCP IAM과 KSA 연결
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Enable IP aliasing
  ip_allocation_policy {               # VPC 네이티브(IP alias) 사용
    cluster_secondary_range_name  = "pods"      # Pods 세컨더리 범위 이름
    services_secondary_range_name = "services"  # Services 세컨더리 범위 이름
  }

  # Enable private cluster
  private_cluster_config {             # 프라이빗 클러스터 구성
    enable_private_nodes    = true     # 노드는 사설 IP만 보유
    enable_private_endpoint = false    # 마스터 엔드포인트는 공용으로 접근(보안그룹으로 제한 권장)
    master_ipv4_cidr_block  = "172.16.0.0/28" # 마스터용 CIDR
  }

  # Enable network policy
  # Autopilot 모드와 network_policy는 충돌 → Autopilot이면 생략
  dynamic "network_policy" {
    for_each = var.enable_autopilot ? [] : [1]
    content {
      enabled = true
    }
  }

  # Enable horizontal pod autoscaling
  addons_config {
    horizontal_pod_autoscaling {
      disabled = false                 # HPA 사용
    }
    http_load_balancing {
      disabled = false                 # HTTP LB(ingress 기본 컨트롤러)
    }
  }

  # Enable logging and monitoring
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"] # Cloud Logging 수집 컴포넌트
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"] # Cloud Monitoring 수집 컴포넌트
  }

  # Master authorized networks
  master_authorized_networks_config {  # 마스터 접근 허용 CIDR(운영 시 제한 권장)
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "All"
    }
  }

  depends_on = [google_compute_router_nat.main] # NAT 생성 후 클러스터 생성
}

# Node Pool (if not using Autopilot)
resource "google_container_node_pool" "main" {
  count = var.enable_autopilot ? 0 : 1            # Autopilot이면 노드풀 생성 안 함

  name       = "${var.cluster_name}-node-pool"
  location   = var.region
  cluster    = google_container_cluster.main.name
  project    = var.project_id
  node_count = var.node_count

  node_config {
    preemptible  = var.preemptible                  # 선점형 여부(비용 절감)
    machine_type = var.machine_type                 # 머신 타입(e2-medium 등)
    disk_size_gb = var.disk_size_gb                 # 디스크 크기
    disk_type    = var.disk_type                    # 디스크 타입(pd-standard 등)

    # Enable Workload Identity
    workload_metadata_config {                       # Workload Identity 메타데이터 모드
      mode = "GKE_METADATA"
    }

    # Enable secure boot
    shielded_instance_config {                       # Shielded Nodes(보안 부팅)
      enable_secure_boot = true
    }

    # Enable OS login
    metadata = {                                     # 레거시 메타데이터 엔드포인트 차단
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [                                 # 노드에서 사용할 OAuth 범위
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {                                       # 노드 라벨
      environment = var.environment
    }

    tags = ["gke-node", "${var.cluster_name}-node"]  # 방화벽 등에 사용할 태그
  }

  management {                                       # 노드 자동 복구/업그레이드
    auto_repair  = true
    auto_upgrade = true
  }

  autoscaling {                                      # 노드풀 자동 확장 범위
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }
}

# NAT Gateway for private nodes
# - Standard 클러스터에서 프라이빗 노드 아웃바운드 통신을 위한 NAT 라우터
resource "google_compute_router" "nat_router" {
  count = var.enable_autopilot ? 0 : 1

  name    = "${var.cluster_name}-nat-router"
  region  = var.region
  network = var.network
}

resource "google_compute_router_nat" "main" {
  count = var.enable_autopilot ? 0 : 1

  name                                = "${var.cluster_name}-nat"
  router                              = google_compute_router.nat_router[0].name
  region                              = var.region
  nat_ip_allocate_option              = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat  = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
