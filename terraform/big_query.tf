# Enables the BigQuery API for your project
resource "google_project_service" "bigquery_api" {
  project = var.gcp_project_id
  service = "bigquery.googleapis.com"
  disable_on_destroy = false
}

resource "google_bigquery_dataset" "weather_dataset" {
  dataset_id                  = "weather_data"
  project                     = var.gcp_project_id
  location                    = var.gcp_region
  description                 = "Dataset for raw and processed weather data."
  friendly_name               = "Weather Data"

  depends_on = [google_project_service.bigquery_api]
}

resource "google_bigquery_table" "raw_weather_json_external" {
  dataset_id = google_bigquery_dataset.weather_dataset.dataset_id
  table_id   = "raw_weather_json"
  project    = var.gcp_project_id
  description = "External table pointing to raw weather JSON data in GCS, with a manually defined schema to handle invalid field names."
  # Set deletion_protection to false to allow Terraform to update the table configuration.
  deletion_protection = false


  external_data_configuration {
    source_format = "NEWLINE_DELIMITED_JSON"
    autodetect    = true 
    source_uris = ["gs://${google_storage_bucket.weather_data_bucket.name}/20250711/output.jsonl"]
  }

  depends_on = [
    google_bigquery_dataset.weather_dataset,
    google_storage_bucket.weather_data_bucket
  ]
}
