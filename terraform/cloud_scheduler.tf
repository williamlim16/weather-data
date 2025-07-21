
resource "google_service_account" "scheduler_sa" {
  project      = var.gcp_project_id
  account_id   = "${var.function_name}-schd"
  display_name = "Service Account for Cloud Scheduler to invoke ${var.function_name}"
  depends_on = [google_project_service.iam_api]
}

resource "google_cloudfunctions_function_iam_member" "scheduler_invoker_permissions" {
  cloud_function = google_cloudfunctions_function.weather_to_gcs_function.name
  project        = google_cloudfunctions_function.weather_to_gcs_function.project
  region         = google_cloudfunctions_function.weather_to_gcs_function.region
  role           = "roles/cloudfunctions.invoker" 
  member         = "serviceAccount:${google_service_account.scheduler_sa.email}"
  depends_on = [
    google_cloudfunctions_function.weather_to_gcs_function,
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

  name        = "${var.function_name}-${lower(replace(each.value.name, " ", "-"))}-${lower(each.value.country)}"
  description = "Triggers weather-to-gcs-function for ${each.value.name}, ${each.value.country}"
  schedule    = "0 * * * *" 
  time_zone   = "Australia/Brisbane" 

  http_target {
    uri         = google_cloudfunctions_function.weather_to_gcs_function.https_trigger_url
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
      audience              = google_cloudfunctions_function.weather_to_gcs_function.https_trigger_url
    }
  }

  attempt_deadline = "180s" # Max time job can run before being retried or marked failed
  project          = var.gcp_project_id
  region           = var.gcp_region # Cloud Scheduler jobs are regional

  depends_on = [
    google_project_service.cloudscheduler_api,
    google_cloudfunctions_function.weather_to_gcs_function,
    google_cloudfunctions_function_iam_member.scheduler_invoker_permissions,
    google_service_account.scheduler_sa
  ]
}
