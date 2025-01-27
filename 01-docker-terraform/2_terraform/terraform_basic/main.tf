terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.6.0"
    }
  }
}

provider "google" {
  project = "terraform-demo-448913"
  region  = "us-central1"
}


resource "google_storage_bucket" "demo-bucket-terraform" {
  name          = "terraform-demo-448913-terra-bucket"
  location      = "US"
  force_destroy = true


  lifecycle_rule {
    condition {
      age = 1
    }
    action {
      type = "AbortIncompleteMultipartUpload"
    }
  }
}

resource "google_bigquery_dataset" "demo_dataset" {
  dataset_id = "demo_dataset"
  project    = "terraform-demo-448913"
  location   = "US"
}