# cloud_function_src/main.py_encode_basestring
import requests
from json.encoder import py_encode_basestring
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


@functions_framework.http
def daily_summary(request):
    """
    Reformat JSON files to single NEWLINE_DELIMITED_JSON file
    """

    request_json = request.get_json(silent=True)
    bucket_name = request_json["bucket_name"] if request_json else None
    subdirectory = request_json.get(
        "subdirectory"
    )  # Get the subdirectory from the request
    output_filename = request_json.get(
        "output_filename", "output.jsonl"
    )  # Default output filename

    if not bucket_name:
        print(f"Error: Missing 'bucket_name' in request.")
        return ("Error: Missing 'bucket_name' in request.", 400)
    prefix = ""
    if subdirectory:
        prefix = subdirectory
        if not prefix.endswith("/"):
            prefix += "/"
        print(f"Processing files in subdirectory: {prefix}")
    else:
        print("Processing all files in the bucket.")

    storage_client = storage.Client(project=GCP_PROJECT_ID)
    bucket = storage_client.bucket(bucket_name)
    blobs = bucket.list_blobs(prefix=prefix)

    output_lines = []

    for blob in blobs:
        if blob.name.endswith(".json"):
            try:
                blob_content = blob.download_as_text()

                data = json.loads(blob_content)

                one_line_json = json.dumps(data)

                output_lines.append(one_line_json)
            except Exception as e:
                print(f"Error processing file {blob.name}: {e}")
        else:
            print(f"Skipping non-JSON file: {blob.name}")

    if not output_lines:
        print("No JSON files found or processed in the bucket.")
        return ("No JSON files found or processed in the bucket.", 200)

    final_output_content = "\n".join(output_lines) + "\n"

    try:
        output_blob = bucket.blob(f"{prefix}{output_filename}")
        output_blob.upload_from_string(
            final_output_content, content_type="application/x-ndjson"
        )
        print(
            f"Successfully created and uploaded {output_filename} to bucket {bucket_name}"
        )
        return (f"Successfully processed files and created {output_filename}", 200)
    except Exception as e:
        print(f"Error uploading the output file {output_filename}: {e}")
        return (f"Error uploading the output file {output_filename}: {e}", 500)


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

    request_json = request.get_json(silent=True)
    city_name = (
        request_json["city_name"] if request_json else os.environ.get("CITY_NAME")
    )
    country_code = (
        request_json["country_code"] if request_json else os.environ.get("COUNTRY_CODE")
    )
    gcs_bucket_name = os.environ.get("GCS_BUCKET_NAME")
    openweather_api_key = os.environ.get("OPENWEATHER_API_KEY")

    print(
        f"Starting weather ETL for {city_name}, {country_code} to GCS bucket: {gcs_bucket_name}..."
    )

    if not all([city_name, country_code, openweather_api_key, gcs_bucket_name]):
        error_msg = "Missing required parameters. Ensure 'city_name' and 'country_code' are in the request body or environment variables, and 'OPENWEATHER_API_KEY' and 'GCS_BUCKET_NAME' are in environment variables."
        print(error_msg)
        return error_msg, 400

    raw_data = fetch_weather_data(city_name, country_code, OPENWEATHER_API_KEY)

    if raw_data:
        # Create a timestamp for the filename
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
        file_name = f"{city_name.lower().replace(' ', '_')}_{timestamp}.json"

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
