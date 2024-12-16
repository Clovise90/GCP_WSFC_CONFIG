# Network resources
resource "google_compute_network" "wsfcnet" {
  name                    = "wsfcnet"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "wsfcnetsub1" {
  name          = "wsfcnetsub1"
  ip_cidr_range = "10.0.0.0/16"
  region        = var.region
  network       = google_compute_network.wsfcnet.id
}

# Firewall rules
resource "google_compute_firewall" "allow-rdp" {
  name    = "allow-rdp"
  network = google_compute_network.wsfcnet.name

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }

  source_ranges = ["0.0.0.0/0"]  # Replace with your IP in production
}

resource "google_compute_firewall" "allow-all-subnet" {
  name    = "allow-all-subnet"
  network = google_compute_network.wsfcnet.name

  allow {
    protocol = "all"
  }

  source_ranges = ["10.0.0.0/16"]
}

resource "google_compute_firewall" "allow-health-check" {
  name    = "allow-health-check"
  network = google_compute_network.wsfcnet.name

  allow {
    protocol = "tcp"
    ports    = ["59998"]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
}

# Reserved IP addresses
resource "google_compute_address" "cluster-access-point" {
  name         = "cluster-access-point"
  region       = var.region
  subnetwork   = google_compute_subnetwork.wsfcnetsub1.id
  address_type = "INTERNAL"
  address      = "10.0.0.8"
}

resource "google_compute_address" "load-balancer-ip" {
  name         = "load-balancer-ip"
  region       = var.region
  subnetwork   = google_compute_subnetwork.wsfcnetsub1.id
  address_type = "INTERNAL"
  address      = "10.0.0.9"
}

# Instance template
locals {
  instance_template = {
    machine_type = "n1-standard-2"
    disk_size_gb = 50
    image        = "windows-sql-cloud/sql-std-2019-win-2022"
  }
}

# Domain Controller
resource "google_compute_instance" "wsfc-dc" {
  name         = "wsfc-dc"
  machine_type = local.instance_template.machine_type
  zone         = var.zone_3

  boot_disk {
    initialize_params {
      image = "windows-sql-cloud/sql-std-2019-win-2022"
      size  = local.instance_template.disk_size_gb
    }
  }

  network_interface {
    network    = google_compute_network.wsfcnet.id
    subnetwork = google_compute_subnetwork.wsfcnetsub1.id
    network_ip = "10.0.0.6"
    access_config {
      //Epemeral public IP
    }
  }

  service_account {
    scopes = ["https://www.googleapis.com/auth/compute"]
  }

  can_ip_forward = true
}

# First Node
resource "google_compute_instance" "wsfc-node-1" {
  name         = "wsfc-node-1"
  machine_type = local.instance_template.machine_type
  zone         = var.zone_1

  boot_disk {
    initialize_params {
      image = "windows-sql-cloud/sql-std-2019-win-2022"
      size  = local.instance_template.disk_size_gb
    }
  }

  network_interface {
    network    = google_compute_network.wsfcnet.id
    subnetwork = google_compute_subnetwork.wsfcnetsub1.id
    network_ip = "10.0.0.4"
    access_config {
        //Ephemeral public IP 
    }
  }

  service_account {
    scopes = ["https://www.googleapis.com/auth/compute"]
  }

  metadata = {
    enable-wsfc = "true"
  }

  can_ip_forward = true
}

# Second Node
resource "google_compute_instance" "wsfc-node-2" {
  name         = "wsfc-node-2"
  machine_type = local.instance_template.machine_type
  zone         = var.zone_2

  boot_disk {
    initialize_params {
      image = "windows-sql-cloud/sql-std-2019-win-2022"
      size  = local.instance_template.disk_size_gb
    }
  }

  network_interface {
    network    = google_compute_network.wsfcnet.id
    subnetwork = google_compute_subnetwork.wsfcnetsub1.id
    network_ip = "10.0.0.5"
    access_config {
        //Ephemeral public Ip
    }
  }

  service_account {
    scopes = ["https://www.googleapis.com/auth/compute"]
  }

  metadata = {
    enable-wsfc = "true"
  }

  can_ip_forward = true
}

# Instance Groups
resource "google_compute_instance_group" "wsfc-group-1" {
  name      = "wsfc-group-1"
  zone      = var.zone_1
  instances = [google_compute_instance.wsfc-node-1.self_link]

  named_port {
    name = "http"
    port = 80
  }
}

resource "google_compute_instance_group" "wsfc-group-2" {
  name      = "wsfc-group-2"
  zone      = var.zone_2
  instances = [google_compute_instance.wsfc-node-2.self_link]

  named_port {
    name = "http"
    port = 80
  }
}

# Health Check
resource "google_compute_health_check" "wsfc-health-check" {
  name               = "wsfc-hc"
  check_interval_sec = 2
  timeout_sec        = 1

  tcp_health_check {
    port         = 59998
    request      = "10.0.0.9"
    response     = "1"
  }
}

# Internal Load Balancer
resource "google_compute_region_backend_service" "wsfc-backend" {
  name                  = "wsfc-backend"
  region                = var.region
  protocol              = "TCP"
  load_balancing_scheme = "INTERNAL"
  connection_draining_timeout_sec = 300
  session_affinity     = "NONE"
  health_checks        = [google_compute_health_check.wsfc-health-check.id]

  backend {
    group          = google_compute_instance_group.wsfc-group-1.self_link
    balancing_mode = "CONNECTION"
  }

  backend {
    group          = google_compute_instance_group.wsfc-group-2.self_link
    balancing_mode = "CONNECTION"
  }

  network = google_compute_network.wsfcnet.id
}

# Forwarding rule
resource "google_compute_forwarding_rule" "wsfc-lb" {
  name                  = "wsfc-lb"
  region                = var.region
  load_balancing_scheme = "INTERNAL"
  backend_service       = google_compute_region_backend_service.wsfc-backend.id
  all_ports            = false
  ports                = ["80"]
  allow_global_access  = false
  network              = google_compute_network.wsfcnet.id
  subnetwork           = google_compute_subnetwork.wsfcnetsub1.id
  ip_address           = google_compute_address.load-balancer-ip.address
}