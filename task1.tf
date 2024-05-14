terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "5.25.0"
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

resource "google_storage_bucket" "armageddon-bucket3" {
  name          = "armageddon-bucket3"
  location      = "US"
  force_destroy = true
}

  resource "google_storage_bucket_iam_binding" "armageddon-bucket3" {
  bucket = google_storage_bucket.armageddon-bucket3.name
  role   = "roles/storage.objectViewer"

  members = [
    "allUsers",
  ]
}
resource "google_storage_bucket_object" "object" {
    name   = "index.html"
    bucket = google_storage_bucket.armageddon-bucket3.name
    source = "/terraform/Armageddon/Task1/Index.html"
    content_type = "text/html"
    
    depends_on = [
        google_storage_bucket.armageddon-bucket3,
        google_storage_bucket_object.object,
    ]
}

output "public_url" {
  value = "https://storage.googleapis.com/${google_storage_bucket.armageddon-bucket3.name}/${google_storage_bucket_object.object.name}"
  description = "The public URL to access the index.html"
}
