# terraform/variables.tf
variable "gcp_project_id" {
  description = "Your Google Cloud Project ID"
  type        = string
}

variable "gcp_region" {
  description = "The GCP region for resources (e.g., australia-southeast2)"
  type        = string
  default     = "australia-southeast1" # Saint Lucia, Queensland, Australia
}

variable "function_name" {
  description = "Name of the Cloud Function"
  type        = string
  default     = "weather-to-gcs-function"
}

variable "openweather_api_key" {
  description = "Your OpenWeatherMap API key"
  type        = string
  sensitive   = true # Mark as sensitive
}

variable "gcs_data_bucket_name" { # New variable for the data bucket
  description = "Name of the GCS bucket to store weather data (must be globally unique)"
  type        = string
  default     = "weather-data-raw-storage-bucket" # Choose a unique name, add project ID to be safe
}

variable "city_name" {
  description = "City to fetch weather data for"
  type        = string
  default     = "Brisbane"
}

variable "country_code" {
  description = "Country code for the city (e.g., AU)"
  type        = string
  default     = "AU"
}

variable "memory_mb" {
  description = "Memory allocated to the Cloud Function in MB"
  type        = number
  default     = 256
}

variable "timeout_seconds" {
  description = "Timeout for the Cloud Function in seconds"
  type        = number
  default     = 60
}
