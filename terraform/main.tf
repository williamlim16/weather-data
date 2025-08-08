# terraform/main.tf

# Enable necessary APIs
resource "google_project_service" "cloudfunctions_api" {
  project = var.gcp_project_id
  service = "cloudfunctions.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloudbuild_api" {
  project = var.gcp_project_id
  service = "cloudbuild.googleapis.com" # Required for Cloud Functions deployment
  disable_on_destroy = false
}

resource "google_project_service" "storage_api" {
  project = var.gcp_project_id
  service = "storage.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "iam_api" {
  project = var.gcp_project_id
  service = "iam.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloudscheduler_api" {
  project = var.gcp_project_id
  service = "cloudscheduler.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "eventarc_api" {
  project = var.gcp_project_id
  service = "eventarc.googleapis.com"
  disable_on_destroy = false
}
