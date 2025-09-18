# VPC
# - 하나의 VPC 네트워크를 생성합니다.
# - auto_create_subnetworks=false 로 설정하여 리전별 자동 서브넷 생성을 비활성화하고
#   우리가 원하는 서브넷을 수동으로 정의합니다(사용자 지정 서브넷 모드).
# - mtu는 네트워크 MTU(최대 전송 단위)로, 1460은 GCP 권장값입니다.
resource "google_compute_network" "main" {
  name                    = var.name           # 생성될 VPC 이름(모듈 입력값)
  auto_create_subnetworks = false              # 자동 서브넷 생성 끔 → 사용자 지정 모드
  mtu                     = 1460               # VPC MTU(바이트)
}

# Subnet
# - 지정한 개수만큼(availability_zones 길이) 서브넷을 생성합니다.
# - 각 서브넷은 리전 단위이며, VPC에 연결됩니다.
# - private_ip_google_access=true 는 프라이빗 IP만으로 Google API에 접근 가능하게 합니다.
# - secondary_ip_range 는 GKE VPC Native(IP Alias)에서
#   Pods/Services 전용 서브넷(세컨더리 범위)을 정의하는 부분입니다.
resource "google_compute_subnetwork" "main" {
  count = length(var.availability_zones)       # 생성할 서브넷 개수(가용영역 수 기준)

  name          = "${var.name}-subnet-${count.index + 1}" # 서브넷 이름
  ip_cidr_range = var.subnet_cidrs[count.index]            # 1차 서브넷 CIDR(노드용)
  region        = var.region                               # 서브넷 리전
  network       = google_compute_network.main.id           # 연결할 VPC

  private_ip_google_access = true                          # 프라이빗 IP로 Google API 접근 허용

  # Pods용 세컨더리 범위(GKE IP alias)
  secondary_ip_range {
    range_name    = "pods"                                  # 범위 이름(클러스터에서 참조)
    ip_cidr_range = var.pods_cidr_ranges[count.index]       # Pods CIDR
  }

  # Services용 세컨더리 범위(GKE IP alias)
  secondary_ip_range {
    range_name    = "services"                              # 범위 이름(클러스터에서 참조)
    ip_cidr_range = var.services_cidr_ranges[count.index]   # Services CIDR
  }
}

# Router
# - Cloud NAT를 붙이기 위한 라우터 자원입니다.
resource "google_compute_router" "main" {
  count = length(var.availability_zones)       # 가용영역 수만큼 생성(선택적 패턴)

  name    = "${var.name}-router-${count.index + 1}" # 라우터 이름
  region  = var.region                             # 라우터 리전(서브넷과 동일 리전)
  network = google_compute_network.main.id         # 연결할 VPC
}

# NAT Gateway
# - 프라이빗 노드/리소스가 인터넷(공용)으로 아웃바운드 통신을 할 수 있도록 NAT를 구성합니다.
resource "google_compute_router_nat" "main" {
  count = 1

  name                                = "${var.name}-nat"
  router                              = google_compute_router.main[0].name
  region                              = var.region
  nat_ip_allocate_option              = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat  = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Firewall Rules
# - 내부 서브넷 간 통신을 허용하는 방화벽 규칙입니다.
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.name}-allow-internal"      # 규칙 이름
  network = google_compute_network.main.name   # 적용할 네트워크

  allow {                                      # TCP 모든 포트 허용(내부 통신용)
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {                                      # UDP 모든 포트 허용(내부 통신용)
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {                                      # ICMP 허용(핑 등)
    protocol = "icmp"
  }

  source_ranges = [                             # 허용 소스 CIDR(예: 두 개의 서브넷)
    var.subnet_cidrs[0],
    var.subnet_cidrs[1]
  ]
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.name}-allow-ssh"          # SSH 허용 규칙(필요 시 IP 제한 권장)
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["22"]                         # TCP 22(SSH)
  }

  source_ranges = ["0.0.0.0/0"]               # 전 구간 허용(운영 시에는 제한 권장)
  target_tags   = ["ssh"]                     # 이 태그가 붙은 인스턴스에만 적용
}

resource "google_compute_firewall" "allow_http" {
  name    = "${var.name}-allow-http"         # HTTP/HTTPS 인바운드 허용 규칙
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]                 # 80/443 포트 허용
  }

  source_ranges = ["0.0.0.0/0"]               # 전 구간 허용(외부 접근용)
  target_tags   = ["http-server"]            # 이 태그가 붙은 인스턴스에만 적용
}

# Egress allow for SMTP (Gmail)
resource "google_compute_firewall" "allow_egress_smtp" {
  name    = "${var.name}-allow-egress-smtp"
  network = google_compute_network.main.name

  direction = "EGRESS"

  allow {
    protocol = "tcp"
    ports    = ["465", "587"]
  }

  destination_ranges = ["0.0.0.0/0"]
}
