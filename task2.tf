terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "5.27.0"
    }
  }
}

provider "google" {
  # Configuration options
  project = "gcp-terraform-project-420321"
  region = "us-central1"
  zone = "us-central1-a"
  credentials = ""
}
resource "google_compute_network" "gcpgentleman_custom_vpc" {
  name                    = "gcpgentleman-custom-vpc"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "gcpgentleman_public_subnet" {
  name          = "us-central-public-subnet-a"
  ip_cidr_range = "10.187.15.0/24"
  region        = "us-central1"
  network       = google_compute_network.gcpgentleman_custom_vpc.self_link
}
resource "google_compute_firewall" "http_firewall" {
  name    = "allow-http"
  network = google_compute_network.gcpgentleman_custom_vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server", "https-server"]
}
resource "google_compute_address" "public_ip" {
  name = "public-ip"
}
resource "google_compute_instance" "default" {
  name         = "armageddon-gcpgentleman-instance"
  machine_type = "e2-medium"
  zone         = "us-central1-a"
  tags = ["http-server"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.gcpgentleman_public_subnet.self_link
    access_config {
      // Ephemeral IP
      nat_ip = google_compute_address.public_ip.address
    }
  }
   metadata = {
    startup-script = "#!/bin/bash\n# Update and install Apache2\napt update\napt install -y apache2\n\n# Start and enable Apache2\nsystemctl start apache2\nsystemctl enable apache2\n\n# GCP Metadata server base URL and header\nMETADATA_URL=\"http://metadata.google.internal/computeMetadata/v1\"\nMETADATA_FLAVOR_HEADER=\"Metadata-Flavor: Google\"\n\n# Use curl to fetch instance metadata\nlocal_ipv4=$(curl -H \"$${METADATA_FLAVOR_HEADER}\" -s \"$${METADATA_URL}/instance/network-interfaces/0/ip\")\npublic_ipv4=$(curl -H \"$${METADATA_FLAVOR_HEADER}\" -s \"$${METADATA_URL}/instance/network-interfaces/0/access-configs/0/external-ip\")\nzone=$(curl -H \"$${METADATA_FLAVOR_HEADER}\" -s \"$${METADATA_URL}/instance/zone\")\nproject_id=$(curl -H \"$${METADATA_FLAVOR_HEADER}\" -s \"$${METADATA_URL}/project/project-id\")\nnetwork_tags=$(curl -H \"$${METADATA_FLAVOR_HEADER}\" -s \"$${METADATA_URL}/instance/tags\")\n\n# Create a simple HTML page and include instance details\ncat <<EOF > /var/www/html/index.html\n<html><body>\n<h2>Enter into Armageddon.</h2>\n<h3>Survival of the Fit Only The Strong Survive!</h3><p><b>Instance Name:</b> $(hostname -f)</p>\n<p><b>Instance Private IP Address: </b> $local_ipv4</p>\n<p><b>Instance Public IP Address: </b> $public_ipv4</p>\n<b>Zone: </b> $zone</p>\n<p><b>Project ID:</b> $project_id</p>\n<p><b>Network Tags:</b> $network_tags</p>\n</body></html>\nEOF"
  }  
}
output "instance_public_ip" {
  value = google_compute_instance.default.network_interface[0].access_config[0].nat_ip
}
