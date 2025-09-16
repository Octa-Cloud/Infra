# VPC
resource "google_compute_network" "main" {
  name                    = var.name
  auto_create_subnetworks = false
  mtu                     = 1460
}

# Subnet
resource "google_compute_subnetwork" "main" {
  count = length(var.availability_zones)

  name          = "${var.name}-subnet-${count.index + 1}"
  ip_cidr_range = var.subnet_cidrs[count.index]
  region        = var.region
  network       = google_compute_network.main.id

  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr_ranges[count.index]
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr_ranges[count.index]
  }
}

# Router
resource "google_compute_router" "main" {
  count = length(var.availability_zones)

  name    = "${var.name}-router-${count.index + 1}"
  region  = var.region
  network = google_compute_network.main.id
}

# NAT Gateway
resource "google_compute_router_nat" "main" {
  count = length(var.availability_zones)

  name                               = "${var.name}-nat-${count.index + 1}"
  router                            = google_compute_router.main[count.index].name
  region                            = var.region
  nat_ip_allocate_option            = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Firewall Rules
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.name}-allow-internal"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [
    var.subnet_cidrs[0],
    var.subnet_cidrs[1]
  ]
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.name}-allow-ssh"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh"]
}

resource "google_compute_firewall" "allow_http" {
  name    = "${var.name}-allow-http"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server"]
}
