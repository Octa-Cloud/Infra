# GKE Cluster
resource "google_container_cluster" "main" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.network
  subnetwork = var.subnetwork

  # Enable Autopilot
  enable_autopilot = var.enable_autopilot

  # Enable Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Enable IP aliasing
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Enable private cluster
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  # Enable network policy
  network_policy {
    enabled = true
  }

  # Enable horizontal pod autoscaling
  addons_config {
    horizontal_pod_autoscaling {
      disabled = false
    }
    http_load_balancing {
      disabled = false
    }
  }

  # Enable logging and monitoring
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }

  # Master authorized networks
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "All"
    }
  }

  depends_on = [google_compute_router_nat.main]
}

# Node Pool (if not using Autopilot)
resource "google_container_node_pool" "main" {
  count = var.enable_autopilot ? 0 : 1

  name       = "${var.cluster_name}-node-pool"
  location   = var.region
  cluster    = google_container_cluster.main.name
  project    = var.project_id
  node_count = var.node_count

  node_config {
    preemptible  = var.preemptible
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    disk_type    = var.disk_type

    # Enable Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Enable secure boot
    shielded_instance_config {
      enable_secure_boot = true
    }

    # Enable OS login
    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      environment = var.environment
    }

    tags = ["gke-node", "${var.cluster_name}-node"]
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }
}

# NAT Gateway for private nodes
resource "google_compute_router" "nat_router" {
  count = var.enable_autopilot ? 0 : 1

  name    = "${var.cluster_name}-nat-router"
  region  = var.region
  network = var.network
}

resource "google_compute_router_nat" "main" {
  count = var.enable_autopilot ? 0 : 1

  name                               = "${var.cluster_name}-nat"
  router                            = google_compute_router.nat_router[0].name
  region                            = var.region
  nat_ip_allocate_option            = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
