resource "google_service_account" "scheduler_sa" {
  project      = var.gcp_project_id
  account_id   = "${var.function_name}-schd"
  display_name = "Service Account for Cloud Scheduler to invoke ${var.function_name}"
  depends_on   = [google_project_service.iam_api]
}

resource "google_cloud_run_v2_service_iam_member" "weather_invoker_permissions" {
  location = google_cloudfunctions2_function.weather_to_gcs_function.location
  name     = google_cloudfunctions2_function.weather_to_gcs_function.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler_sa.email}"
  depends_on = [
    google_cloudfunctions2_function.weather_to_gcs_function,
    google_service_account.scheduler_sa
  ]
}

resource "google_cloud_run_v2_service_iam_member" "daily_summary_invoker_permissions" {
  location = google_cloudfunctions2_function.daily_summary.location
  name     = google_cloudfunctions2_function.daily_summary.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler_sa.email}"
  
  depends_on = [
    google_cloudfunctions2_function.daily_summary,
    google_service_account.scheduler_sa
  ]
}

locals {
  cities = [
    { name = "Brisbane", country = "AU" },
    { name = "Sydney",   country = "AU" },
    { name = "Melbourne", country = "AU" },
  ]
}

resource "google_cloud_scheduler_job" "weather_scheduler_job" {
  for_each = { for city in local.cities : "${city.name}-${city.country}" => city }

  name             = "${var.function_name}-${lower(replace(each.value.name, " ", "-"))}-${lower(each.value.country)}"
  description      = "Triggers weather-to-gcs-function for ${each.value.name}, ${each.value.country}"
  schedule         = "0 * * * *"
  time_zone        = "Australia/Brisbane"
  attempt_deadline = "180s"
  project          = var.gcp_project_id
  region           = var.gcp_region
  
  http_target {
    uri         = google_cloudfunctions2_function.weather_to_gcs_function.url
    http_method = "POST"
    body        = base64encode(jsonencode({
      city_name    = each.value.name,
      country_code = each.value.country
    }))
    headers = {
      "Content-Type" = "application/json"
    }
    oidc_token {
      service_account_email = google_service_account.scheduler_sa.email
      audience              = google_cloudfunctions2_function.weather_to_gcs_function.url
    }
  }

  depends_on = [
    google_project_service.cloudscheduler_api,
    google_cloudfunctions2_function.weather_to_gcs_function,
    google_cloud_run_v2_service_iam_member.weather_invoker_permissions,
    google_service_account.scheduler_sa
  ]
}

resource "google_cloud_scheduler_job" "daily_summary_job" {
  name             = "daily_summarizer"
  description      = "Triggers daily summarizer"
  schedule         = "0 0 * * *"
  time_zone        = "Australia/Brisbane"
  attempt_deadline = "180s"
  project          = var.gcp_project_id
  region           = var.gcp_region

  http_target {
    uri         = google_cloudfunctions2_function.daily_summary.url
    http_method = "POST"
    body        = base64encode(jsonencode({
      bucket_name  = google_storage_bucket.weather_data_bucket.name
      subdirectory = formatdate("YYYYMMDD", timeadd(timestamp(), "-24h"))
    }))
    headers = {
      "Content-Type" = "application/json"
    }
    oidc_token {
      service_account_email = google_service_account.scheduler_sa.email
      audience              = google_cloudfunctions2_function.daily_summary.url
    }
  }

  depends_on = [
    google_project_service.cloudscheduler_api,
    google_cloudfunctions2_function.daily_summary,
    google_cloud_run_v2_service_iam_member.daily_summary_invoker_permissions,
    google_service_account.scheduler_sa
  ]
}
