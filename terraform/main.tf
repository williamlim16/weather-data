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

# *** ADD THIS MISSING API ENABLING FOR IAM ***
resource "google_project_service" "iam_api" {
  project = var.gcp_project_id
  service = "iam.googleapis.com"
  disable_on_destroy = false
}

# 1. Cloud Storage Bucket for storing weather data files
resource "google_storage_bucket" "weather_data_bucket" {
  name          = "${var.gcs_data_bucket_name}-${var.gcp_project_id}" # Make it unique by appending project ID
  location      = var.gcp_region
  project       = var.gcp_project_id
  force_destroy = true # Be careful: allows deletion of non-empty buckets
  uniform_bucket_level_access = true
  depends_on = [google_project_service.storage_api]
}

# 2. Cloud Storage Bucket for Cloud Function Source Code (separate from data bucket)
resource "google_storage_bucket" "function_source_bucket" {
  name          = "${var.gcp_project_id}-cloud-function-sources-v1" # Unique name for source code
  location      = var.gcp_region
  project       = var.gcp_project_id
  force_destroy = true
  uniform_bucket_level_access = true
  depends_on = [google_project_service.storage_api]
}

# 3. Archive the Cloud Function source code
data "archive_file" "function_source_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../cloud_functions" # Path to your Python source code
  output_path = "${path.module}/cloud_function_src.zip"
}

# 4. Upload the zipped source code to the GCS source bucket
resource "google_storage_bucket_object" "function_source_object" {
  name         = "weather-to-gcs-function-${data.archive_file.function_source_zip.output_md5}.zip"
  bucket       = google_storage_bucket.function_source_bucket.name
  source       = data.archive_file.function_source_zip.output_path
  content_type = "application/zip"
  depends_on = [google_storage_bucket.function_source_bucket, data.archive_file.function_source_zip]
}

# 5. Create a Service Account for the Cloud Function
resource "google_service_account" "function_sa" {
  project      = var.gcp_project_id
  account_id   = "${var.function_name}-sa"
  display_name = "Service Account for ${var.function_name} Cloud Function"
  # Add dependency on the IAM API enablement
  depends_on = [google_project_service.iam_api]
}

# Grant the Cloud Function's Service Account permissions to write to the data bucket
resource "google_storage_bucket_iam_member" "data_bucket_writer" {
  bucket = google_storage_bucket.weather_data_bucket.name
  role   = "roles/storage.objectAdmin" # objectAdmin allows creating, reading, updating, deleting objects
  member = "serviceAccount:${google_service_account.function_sa.email}"
  depends_on = [google_storage_bucket.weather_data_bucket, google_service_account.function_sa]
}

# 6. Deploy the Cloud Function
resource "google_cloudfunctions_function" "weather_to_gcs_function" {
  name                  = var.function_name
  project               = var.gcp_project_id
  region                = var.gcp_region
  runtime               = "python311"
  entry_point           = "weather_to_gcs_function"
  source_archive_bucket = google_storage_bucket.function_source_bucket.name
  source_archive_object = google_storage_bucket_object.function_source_object.name
  timeout               = var.timeout_seconds
  available_memory_mb   = var.memory_mb
  service_account_email = google_service_account.function_sa.email

  trigger_http = true

  environment_variables = {
    OPENWEATHER_API_KEY = var.openweather_api_key
    GCP_PROJECT_ID      = var.gcp_project_id
    GCS_BUCKET_NAME     = google_storage_bucket.weather_data_bucket.name
    CITY_NAME           = var.city_name
    COUNTRY_CODE        = var.country_code
  }

  depends_on = [
    google_project_service.cloudfunctions_api,
    google_project_service.cloudbuild_api,
    google_storage_bucket_object.function_source_object,
    google_service_account.function_sa,
    google_storage_bucket_iam_member.data_bucket_writer,
    google_project_service.iam_api # Add this explicit dependency as well
  ]
}

# Optional: Allow unauthenticated access if you want to test from browser (NOT recommended for prod)
resource "google_cloudfunctions_function_iam_member" "invoker_permissions" {
  count          = 0 # Set to 1 to enable, 0 to disable (best to keep disabled)
  project        = google_cloudfunctions_function.weather_to_gcs_function.project
  region         = google_cloudfunctions_function.weather_to_gcs_function.region
  cloud_function = google_cloudfunctions_function.weather_to_gcs_function.name
  role           = "roles/cloudfunctions.invoker"
  member         = "allUsers"
  depends_on     = [google_cloudfunctions_function.weather_to_gcs_function]
}
