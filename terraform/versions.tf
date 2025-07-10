# terraform/versions.tf
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    bucket  = "1601-terraform-bucket-state" 
    prefix  = "terraform/state/weather-etl-v1"
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}
