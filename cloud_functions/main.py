# cloud_function_src/main.py

import requests
import json
import os
from datetime import datetime, timezone
from google.cloud import storage  # Import GCS client
import functions_framework  # Required for Cloud Functions HTTP trigger

# --- Configuration (will be passed via environment variables from Terraform) ---
OPENWEATHER_API_KEY = os.environ.get("OPENWEATHER_API_KEY")
GCP_PROJECT_ID = os.environ.get("GCP_PROJECT_ID")
GCS_BUCKET_NAME = os.environ.get(
    "GCS_BUCKET_NAME"
)  # New environment variable for bucket name
CITY_NAME = os.environ.get("CITY_NAME")
COUNTRY_CODE = os.environ.get("COUNTRY_CODE")

# Initialize GCS client globally
gcs_client = storage.Client(project=GCP_PROJECT_ID)


def fetch_weather_data(city, country_code, api_key):
    """Fetches current weather data from OpenWeatherMap API."""
    base_url = "http://api.openweathermap.org/data/2.5/weather"
    params = {"q": f"{city},{country_code}", "appid": api_key, "units": "metric"}
    try:
        response = requests.get(base_url, params=params)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"Error fetching data for {city}: {e}")
        return None


def save_to_gcs(bucket_name, file_content, file_name):
    """Saves content as a file to a GCS bucket."""
    try:

        timestamp = datetime.now(timezone.utc).strftime("%Y%m%d")
        bucket = gcs_client.bucket(bucket_name)
        blob = bucket.blob(f"{timestamp}/{file_name}")

        # Upload the string content
        blob.upload_from_string(file_content, content_type="application/json")

        print(f"File '{file_name}' uploaded successfully to bucket '{bucket_name}'.")
        return True
    except Exception as e:
        print(f"Error uploading file to GCS: {e}")
        return False


@functions_framework.http
def weather_to_gcs_function(request):
    """
    Cloud Function entry point for HTTP trigger.
    Fetches weather data and saves it to a GCS bucket.
    """
    print(
        f"Starting weather ETL for {CITY_NAME}, {COUNTRY_CODE} to GCS bucket: {GCS_BUCKET_NAME}..."
    )

    raw_data = fetch_weather_data(CITY_NAME, COUNTRY_CODE, OPENWEATHER_API_KEY)

    if raw_data:
        # Create a timestamp for the filename
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
        file_name = f"{CITY_NAME.lower().replace(' ', '_')}_{timestamp}.json"

        # Convert raw_data (dictionary) to a JSON string for saving
        json_content = json.dumps(raw_data, indent=2)

        if save_to_gcs(GCS_BUCKET_NAME, json_content, file_name):
            return (
                f"Weather data for {CITY_NAME} saved to GCS successfully: {file_name}",
                200,
            )
        else:
            return "Error: Failed to save data to GCS.", 500
    else:
        print("Failed to fetch raw weather data.")
        return "Error: Failed to fetch raw weather data.", 500
