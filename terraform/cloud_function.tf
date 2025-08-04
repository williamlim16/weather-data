
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

resource "google_cloudfunctions_function" "daily_summary" {
  name                  = var.function_daily_name
  project               = var.gcp_project_id
  region                = var.gcp_region
  runtime               = "python311"
  entry_point           = "daily_summary"
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
