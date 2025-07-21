

resource "google_storage_bucket" "weather_data_bucket" {
  name          = "${var.gcs_data_bucket_name}-${var.gcp_project_id}" # Make it unique by appending project ID
  location      = var.gcp_region
  project       = var.gcp_project_id
  force_destroy = false
  uniform_bucket_level_access = true
  depends_on = [google_project_service.storage_api]
}

resource "google_storage_bucket" "function_source_bucket" {
  name          = "${var.gcp_project_id}-cloud-function-sources-v1" # Unique name for source code
  location      = var.gcp_region
  project       = var.gcp_project_id
  force_destroy = true
  uniform_bucket_level_access = true
  depends_on = [google_project_service.storage_api]
}
