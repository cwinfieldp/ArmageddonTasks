terraform {
required_providers {
 google = {
   source = "hashicorp/google"
   version = "5.28.0"
 }
}
}
provider "google" {
# Configuration options
project = "gcp-terraform-project-420321"
region = "us-central1"
zone = "us-central1-a"
credentials = "gcp-terraform-project-420321-f2cc606dad59.json"
}

#Create 3 VPCs in different regions

resource "google_compute_network" "gaming-vpc-eu" {
name                    = "gaming-vpc-eu"
auto_create_subnetworks = "false"
}
resource "google_compute_network" "gaming-vpc-us" {
name                    = "gaming-vpc-us"
auto_create_subnetworks = "false"
}
resource "google_compute_network" "gaming-vpc-asia" {
name                    = "gaming-vpc-asia"
auto_create_subnetworks = "false"
}

#create subnets in each VPC

resource "google_compute_subnetwork" "gaming_subnet_eu" {
name          = "gaming-subnet-eu"
ip_cidr_range = "10.187.15.0/24"
region        = "europe-west4"
network       = google_compute_network.gaming-vpc-eu.self_link
}
resource "google_compute_subnetwork" "gaming_subnet1_us" {
name          = "gaming-subnet1-us"
ip_cidr_range = "172.16.15.0/24"
region        = "us-central1"
network       = google_compute_network.gaming-vpc-us.self_link
}
resource "google_compute_subnetwork" "gaming_subnet2_us" {
name          = "gaming-subnet2-us"
ip_cidr_range = "172.16.25.0/24"
region        = "us-east1"
network       = google_compute_network.gaming-vpc-us.self_link
}
resource "google_compute_subnetwork" "gaming_subnet_asia" {
name          = "gaming-subnet-asia"
ip_cidr_range = "192.168.15.0/24"
region        = "asia-northeast1"
network       = google_compute_network.gaming-vpc-asia.self_link
}

#create firewall rules

resource "google_compute_firewall" "icmp_firewall" {
name    = "allow-icmp"
network = google_compute_network.gaming-vpc-eu.self_link

allow {
 protocol = "icmp"
}
source_ranges = ["0.0.0.0/0"]
target_tags   = ["gaming-hq"]
}
resource "google_compute_firewall" "rdp_firewall" {
name    = "allow-rdp"
network = google_compute_network.gaming-vpc-asia.self_link


allow {
 protocol = "tcp"
 ports = ["3389"]
 }
source_ranges = ["0.0.0.0/0"]
target_tags   = ["gaming-asia-agent"]
}
resource "google_compute_firewall" "http_firewall" {
 name    = "allow-http"
 network = google_compute_network.gaming-vpc-eu.self_link


 allow {
   protocol = "tcp"
   ports    = ["22","80"]
 }

 source_tags   = ["gaming-asia-agent"]
 target_tags   = ["gaming-hq"]
}
resource "google_compute_firewall" "http_firewall2" {
 name    = "allow-http2"
 network = google_compute_network.gaming-vpc-eu.self_link


 allow {
   protocol = "tcp"
   ports    = ["22","80"]
 }

 source_ranges   = ["172.16.15.0/24","172.16.25.0/24"]
 target_tags   = ["gaming-hq"]
}
resource "google_compute_firewall" "rdp_firewall2" {
 name    = "allow-rdp2"
 network = google_compute_network.gaming-vpc-us.self_link

 allow {
   protocol = "tcp"
   ports    = ["3389"]
 }
 source_ranges = ["0.0.0.0/0"]
 target_tags   = ["gaming-us-agent"]
}
resource "google_compute_firewall" "http_firewall_asia" {
 name    = "allow-http-asia"
 network = google_compute_network.gaming-vpc-asia.self_link

 allow {
   protocol = "tcp"
   ports    = ["80"]
 }
 source_ranges = ["192.168.15.0/24"]
 target_tags = ["gaming-hq"]
}

#Create firewall rules for internal traffic

resource "google_compute_firewall" "internal-asia" {
  name    = "allow-internal"
  network = google_compute_network.gaming-vpc-asia.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  source_ranges = ["10.187.15.0/24"]
}
resource "google_compute_firewall" "internal-eu" {
  name    = "allow-internal2"
  network = google_compute_network.gaming-vpc-eu.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  source_ranges = ["192.168.15.0/24"]
}

#create static IP addresses for each instance

resource "google_compute_address" "vm_eu_ip" {
 name   = "vm-eu-ip"
 region = "europe-west4"
}
resource "google_compute_address" "vm_asia_ip" {
 name   = "vm-asia-ip"
 region = "asia-northeast1"
}
resource "google_compute_address" "vm_us_ip" {
 name   = "vm-us-ip"
 region = "us-central1"
}
resource "google_compute_address" "vm_us2_ip" {
 name   = "vm-us2-ip"
 region = "us-east1"
}

#create VM instances

resource "google_compute_instance" "vm-eu" {
name         = "gaming-instance-eu"
machine_type = "e2-medium"
zone         = "europe-west4-a"
tags = ["gaming-hq"]

boot_disk {
 initialize_params {
   image = "debian-cloud/debian-10"
 }
}
network_interface {
 subnetwork = google_compute_subnetwork.gaming_subnet_eu.self_link


 access_config {
     nat_ip = google_compute_address.vm_eu_ip.address
   }

 }
 can_ip_forward = true
 metadata = {    
  startup-script = "#!/bin/bash\n# Update and install Apache2\napt update\napt install -y apache2\n\n# Start and enable Apache2\nsystemctl start apache2\nsystemctl enable apache2\n\n# GCP Metadata server base URL and header\nMETADATA_URL=\"http://metadata.google.internal/computeMetadata/v1\"\nMETADATA_FLAVOR_HEADER=\"Metadata-Flavor: Google\"\n\n# Use curl to fetch instance metadata\nlocal_ipv4=$(curl -H \"$${METADATA_FLAVOR_HEADER}\" -s \"$${METADATA_URL}/instance/network-interfaces/0/ip\")\npublic_ipv4=$(curl -H \"$${METADATA_FLAVOR_HEADER}\" -s \"$${METADATA_URL}/instance/network-interfaces/0/access-configs/0/external-ip\")\nzone=$(curl -H \"$${METADATA_FLAVOR_HEADER}\" -s \"$${METADATA_URL}/instance/zone\")\nproject_id=$(curl -H \"$${METADATA_FLAVOR_HEADER}\" -s \"$${METADATA_URL}/project/project-id\")\nnetwork_tags=$(curl -H \"$${METADATA_FLAVOR_HEADER}\" -s \"$${METADATA_URL}/instance/tags\")\n\n# Create a simple HTML page and include instance details\ncat <<EOF > /var/www/html/index.html\n<html><body>\n<h2>Enter into Armageddon.</h2>\n<h3>Survival of the Fit Only The Strong Survive!</h3><p><b>Instance Name:</b> $(hostname -f)</p>\n<p><b>Instance Private IP Address: </b> $local_ipv4</p>\n<p><b>Instance Public IP Address: </b> $public_ipv4</p>\n<b>Zone: </b> $zone</p>\n<p><b>Project ID:</b> $project_id</p>\n<p><b>Network Tags:</b> $network_tags</p>\n</body></html>\nEOF"
 }
}
resource "google_compute_instance" "vm-us" {
name         = "gaming-instance-us"
machine_type = "e2-medium"
zone         = "us-central1-a"
tags = ["gaming-us-agent"]
boot_disk {
 initialize_params {
   image = "windows-server-2019-dc-v20210914"
 }
}
network_interface {
 subnetwork = google_compute_subnetwork.gaming_subnet1_us.self_link
  access_config {
     nat_ip = google_compute_address.vm_us_ip.address
   }
 }
 can_ip_forward = true
 metadata = {
   windows-startup-script-ps1 = <<-EOF
   $password = ConvertTo-SecureString 'password' -AsPlainText -Force
   $user = New-LocalUser -Name 'remote_user' -Password $password -FullName 'Remote User' -Description 'Remote User for VM in Asia'
   Add-LocalGroupMember -Group 'Administrators' -Member $user.Name
   EOF
 }
}
resource "google_compute_instance" "vm-us2" {
name         = "gaming-instance-us2"
machine_type = "e2-medium"
zone         = "us-east1-b"
tags = ["gaming-us-agent"]
boot_disk {
 initialize_params {
   image = "windows-server-2019-dc-v20210914"
 }
}
network_interface {
 subnetwork = google_compute_subnetwork.gaming_subnet2_us.self_link
  access_config {
     nat_ip = google_compute_address.vm_us2_ip.address
   }
 }
 can_ip_forward = true
 metadata = {
   windows-startup-script-ps1 = <<-EOF
   $password = ConvertTo-SecureString 'password' -AsPlainText -Force
   $user = New-LocalUser -Name 'remote_user' -Password $password -FullName 'Remote User' -Description 'Remote User for VM in Asia'
   Add-LocalGroupMember -Group 'Administrators' -Member $user.Name
   EOF
 }
}
resource "google_compute_instance" "vm-asia" {
name         = "gaming-instance-asia"
machine_type = "e2-medium"
zone         = "asia-northeast1-a"
tags = ["gaming-asia-agent"]
boot_disk {
 initialize_params {
   image = "windows-server-2019-dc-v20210914"
 }
}
network_interface {
 subnetwork = google_compute_subnetwork.gaming_subnet_asia.self_link
  access_config {
     nat_ip = google_compute_address.vm_asia_ip.address
   }
}
can_ip_forward = true
 metadata = {
   windows-startup-script-ps1 = <<-EOF
   $password = ConvertTo-SecureString 'password' -AsPlainText -Force
   $user = New-LocalUser -Name 'remote_user' -Password $password -FullName 'Remote User' -Description 'Remote User for VM in Asia'
   Add-LocalGroupMember -Group 'Administrators' -Member $user.Name
   EOF
 }
}

# Create IP for Gateways

resource "google_compute_address" "gateway_asia" {
  name = "gateway-asia"
  region = "asia-northeast1"
 
}
resource "google_compute_address" "gateway_eu" {
  name = "gateway-eu"
  region = "europe-west4"
}

# create Gateways
  
resource "google_compute_vpn_gateway" "target_gateway_asia" {
  name    = "vpn-1"
  network = google_compute_network.gaming-vpc-asia.id
  region = "asia-northeast1"

}

resource "google_compute_vpn_gateway" "target_gateway_eu" {
  name    = "vpn-2"
  network = google_compute_network.gaming-vpc-eu.id
  region = "europe-west4"
}

# create forwarding rules

resource "google_compute_forwarding_rule" "fr_esp" {
  name        = "fr-esp"
  ip_protocol = "ESP"
  region = "asia-northeast1"
  ip_address  = google_compute_address.gateway_asia.address
  target      = google_compute_vpn_gateway.target_gateway_asia.self_link
}

resource "google_compute_forwarding_rule" "fr_udp500" {
  name        = "fr-udp500"
  ip_protocol = "UDP"
  port_range  = "500"
  region = "asia-northeast1"
  ip_address  = google_compute_address.gateway_asia.address
  target      = google_compute_vpn_gateway.target_gateway_asia.self_link
}

resource "google_compute_forwarding_rule" "fr_udp4500" {
  name        = "fr-udp4500"
  ip_protocol = "UDP"
  port_range  = "4500"
  region = "asia-northeast1"
  ip_address  = google_compute_address.gateway_asia.address
  target      = google_compute_vpn_gateway.target_gateway_asia.self_link
}

resource "google_compute_forwarding_rule" "fr2_esp" {
  name        = "fr2-esp"
  ip_protocol = "ESP"
  region = "europe-west4"
  ip_address  = google_compute_address.gateway_eu.address
  target      = google_compute_vpn_gateway.target_gateway_eu.self_link
}

resource "google_compute_forwarding_rule" "fr2_udp500" {
  name        = "fr2-udp500"
  ip_protocol = "UDP"
  port_range  = "500"
  region = "europe-west4"
  ip_address  = google_compute_address.gateway_eu.address
  target      = google_compute_vpn_gateway.target_gateway_eu.self_link
}

resource "google_compute_forwarding_rule" "fr2_udp4500" {
  name        = "fr2-udp4500"
  ip_protocol = "UDP"
  port_range  = "4500"
  region = "europe-west4"
  ip_address  = google_compute_address.gateway_eu.address
  target      = google_compute_vpn_gateway.target_gateway_eu.self_link
}

#create VPN tunnels

resource "google_compute_vpn_tunnel" "tunnel1" {
  name          = "tunnel-1"
  peer_ip       = google_compute_address.gateway_eu.address

  shared_secret = "N08eIuXsQBZeuUxVjyP3fhLGjbcI8c5S"
  
  local_traffic_selector = ["192.168.15.0/24"]
  remote_traffic_selector= ["10.187.15.0/24"]
  target_vpn_gateway = google_compute_vpn_gateway.target_gateway_asia.self_link
  
  ike_version = 2

  depends_on = [
    google_compute_forwarding_rule.fr_esp,
    google_compute_forwarding_rule.fr_udp500,
    google_compute_forwarding_rule.fr_udp4500,
  ]

  labels = {
    foo = "bar"
  }
}

resource "google_compute_vpn_tunnel" "tunnel2" {
  name          = "tunnel-2"
  peer_ip       = google_compute_address.gateway_asia.address
  shared_secret = "N08eIuXsQBZeuUxVjyP3fhLGjbcI8c5S"
  local_traffic_selector = ["10.187.15.0/24"]  
  remote_traffic_selector= ["192.168.15.0/24"] 

  target_vpn_gateway = google_compute_vpn_gateway.target_gateway_eu.self_link
  
  ike_version = 2

  depends_on = [
    google_compute_forwarding_rule.fr2_esp,
    google_compute_forwarding_rule.fr2_udp500,
    google_compute_forwarding_rule.fr2_udp4500,
  ]

  labels = {
    foo = "bar"
  }
}

# create routes

resource "google_compute_route" "route1" {
  name       = "route1"
  network    = google_compute_network.gaming-vpc-asia.name
  dest_range = "10.187.15.0/24"
  priority   = 1000

  next_hop_vpn_tunnel = google_compute_vpn_tunnel.tunnel1.id
  depends_on = [ google_compute_vpn_tunnel.tunnel1 ]
}
resource "google_compute_route" "route2" {
  name       = "route2"
  network    = google_compute_network.gaming-vpc-eu.id
  dest_range = "192.168.15.0/24"
  priority   = 1000

  next_hop_vpn_tunnel = google_compute_vpn_tunnel.tunnel2.id
  depends_on = [ google_compute_vpn_tunnel.tunnel2 ]
}

#create network peering

resource "google_compute_network_peering" "peering1-eu" {
 name         = "peering1-eu"
 network      = google_compute_network.gaming-vpc-eu.self_link
 peer_network = google_compute_network.gaming-vpc-us.self_link
}

resource "google_compute_network_peering" "peering2-us" {
 name         = "peering2-us"
 network      = google_compute_network.gaming-vpc-us.self_link
 peer_network = google_compute_network.gaming-vpc-eu.self_link
}

