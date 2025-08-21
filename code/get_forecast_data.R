#!/usr/bin/env Rscript

# get_forecast_data.R
# -------------------
# Purpose: Download 7-day municipal weather forecasts from AEMET OpenData API
#
# This script fetches daily weather forecasts for ALL Spanish municipalities using codes
# from data/municipalities.csv.gz. The CUMUN variable contains 8,129 municipality codes.
#
# Concurrency Control:
#   - Set PREVENT_CONCURRENT_RUNS = TRUE to enable lockfile-based run prevention
#   - Set PREVENT_CONCURRENT_RUNS = FALSE (default) to allow multiple concurrent runs
#
# Scale Control:
#   - Set SAMPLE_SIZE to a number (e.g., 50) for testing with a subset of municipalities
#   - Set SAMPLE_SIZE = NULL to process all 8,129 municipalities (will take several hours)
#
# Output: Municipal-level daily forecasts with variables compatible with observation data
#
# Core Variables:
#   - temperatura.maxima: Maximum temperature (°C)
#   - temperatura.minima: Minimum temperature (°C) 
#   - temperatura.dato: Representative temperature (°C)
#   - humedadRelativa.maxima: Maximum relative humidity (%)
#   - humedadRelativa.minima: Minimum relative humidity (%)
#   - humedadRelativa.dato: Representative humidity (%)
#   - probPrecipitacion: Precipitation probability (%)
#   - rachaMax: Maximum wind gust (km/h)
#   - viento: Wind information
#
# Usage:
#   - Requires a valid API key in 'auth/keys.R' as 'my_api_key'
#   - Run as an R script. Output written to 'data/spain_weather_municipal_forecast.csv.gz'
#
# Dependencies: tidyverse, lubridate, curl, jsonlite, data.table
#
# Author: John Palmer  
# Date: 2025-08-20

rm(list=ls())

# Dependencies ####
library(tidyverse)
library(lubridate)
library(curl)
library(jsonlite)
library(data.table)

# If you want to prevent concurrent runs of this script, set PREVENT_CONCURRENT_RUNS to TRUE.
PREVENT_CONCURRENT_RUNS = FALSE

if(PREVENT_CONCURRENT_RUNS) {
  # Prevent concurrent runs by creating a lockfile
  # Lockfile management
  lockfile <- "tmp/get_forecast_data.lock"
  # Check if lockfile exists
  if (file.exists(lockfile)) {
    cat("Another forecast run is in progress. Exiting.\n")
    quit(save = "no", status = 0)
  }
  # Create a temporary directory and lockfile
  dir.create("tmp", showWarnings = FALSE)
  file.create(lockfile)
  # Ensure lockfile is removed on exit
  on.exit(unlink(lockfile), add = TRUE)
}

# Load API keys
source("auth/keys.R")

# Create curl handle with initial API key
h <- new_handle()
handle_setheaders(h, 'api_key' = my_api_key)

# Function to update curl handle with current API key
update_curl_handle <- function() {
  current_key <- get_current_api_key()
  handle_setheaders(h, 'api_key' = current_key)
}

# Function to debug API response for a municipality
debug_municipal_forecast = function(municipio_code) {
  cat("=== DEBUG: Municipality", municipio_code, "===\n")
  
  tryCatch({
    # Request forecast data
    req = curl_fetch_memory(paste0('https://opendata.aemet.es/opendata/api/prediccion/especifica/municipio/diaria/', municipio_code), handle=h)
    cat("Status code:", req$status_code, "\n")
    
    if(req$status_code != 200) {
      cat("Request failed, raw response:", rawToChar(req$content), "\n")
      return(NULL)
    }
    
    response_content = fromJSON(rawToChar(req$content))
    cat("Response keys:", names(response_content), "\n")
    
    if("datos" %in% names(response_content)) {
      # Get actual forecast data
      req2 = curl_fetch_memory(response_content$datos)
      cat("Data URL status:", req2$status_code, "\n")
      
      if(req2$status_code == 200) {
        this_string = rawToChar(req2$content)
        Encoding(this_string) = "latin1"
        cat("Raw data length:", nchar(this_string), "characters\n")
        cat("First 200 chars:", substr(this_string, 1, 200), "\n")
        
        forecast_data = fromJSON(this_string, flatten = FALSE)
        cat("Parsed data keys:", names(forecast_data), "\n")
        
        if("prediccion.dia" %in% names(forecast_data)) {
          cat("Prediction days structure:", str(forecast_data$prediccion.dia), "\n")
        }
      }
    }
  }, error = function(e) {
    cat("DEBUG ERROR:", e$message, "\n")
    cat("This suggests API connectivity issues, not code problems.\n")
  })
  cat("=== END DEBUG ===\n\n")
}

# Function to get municipal forecast data with API key rotation
get_municipal_forecast = function(municipio_code) {
  tryCatch({
    # Request forecast data with timeout and retry logic
    req = tryCatch({
      curl_fetch_memory(paste0('https://opendata.aemet.es/opendata/api/prediccion/especifica/municipio/diaria/', municipio_code), handle=h)
    }, error = function(e) {
      if(grepl("Server returned nothing|Empty reply", e$message)) {
        cat("Server connectivity issue for municipality", municipio_code, "- skipping\n")
        return(list(status_code = 0, content = raw(0)))  # Return empty but valid structure
      } else {
        stop(e)  # Re-throw other errors
      }
    })
    
    if(req$status_code == 0) {
      return(NULL)  # Server connectivity issue
    }
    
    # Handle rate limiting with API key rotation
    if(req$status_code == 429) {
      cat("Rate limit hit for municipality", municipio_code, "- rotating API key\n")
      rotate_api_key()
      update_curl_handle()
      
      # Wait a bit longer before retrying
      Sys.sleep(5)
      
      # Retry with new key
      req = tryCatch({
        curl_fetch_memory(paste0('https://opendata.aemet.es/opendata/api/prediccion/especifica/municipio/diaria/', municipio_code), handle=h)
      }, error = function(e) {
        if(grepl("Server returned nothing|Empty reply", e$message)) {
          cat("Server connectivity issue for municipality", municipio_code, "after key rotation - skipping\n")
          return(list(status_code = 0, content = raw(0)))
        } else {
          stop(e)
        }
      })
      
      if(req$status_code == 0) {
        return(NULL)
      }
    }
    
    if(req$status_code != 200) {
      cat("API request failed for municipality", municipio_code, "with status:", req$status_code, "\n")
      return(NULL)
    }
    
    response_content = fromJSON(rawToChar(req$content))
    
    if(!"datos" %in% names(response_content)) {
      cat("No data URL in response for municipality", municipio_code, "\n")
      return(NULL)
    }
    
    # Get actual forecast data
    req2 = curl_fetch_memory(response_content$datos)
    
    if(req2$status_code != 200) {
      cat("Forecast data request failed for municipality", municipio_code, "with status:", req2$status_code, "\n")
      return(NULL)
    }
    
    this_string = rawToChar(req2$content)
    Encoding(this_string) = "latin1"  # Handle encoding
    forecast_data = fromJSON(this_string, flatten = FALSE)  # Changed to FALSE for proper structure
    
    # Debug: Check if we have the expected structure
    if(is.null(forecast_data) || length(forecast_data) == 0) {
      cat("Empty forecast data for municipality", municipio_code, "\n")
      return(NULL)
    }
    
    # Extract municipality info with safe checking
    municipio_nombre = if("nombre" %in% names(forecast_data) && length(forecast_data$nombre) > 0) forecast_data$nombre else "Unknown"
    municipio_provincia = if("provincia" %in% names(forecast_data) && length(forecast_data$provincia) > 0) forecast_data$provincia else "Unknown"
    elaborado = if("elaborado" %in% names(forecast_data) && length(forecast_data$elaborado) > 0) forecast_data$elaborado else NA
    
    # Extract daily forecasts with safe checking
    if(!"prediccion.dia" %in% names(forecast_data) || length(forecast_data$prediccion.dia) == 0) {
      cat("No prediction days found for municipality", municipio_code, "\n")
      return(NULL)
    }
    
    pred_days = forecast_data$prediccion.dia[[1]]
    
    if(is.null(pred_days) || nrow(pred_days) == 0) {
      cat("No forecast days for municipality", municipio_code, "\n")
      return(NULL)
    }
    
    # Process each forecast day
    forecast_list = list()
    
    for(i in seq_len(nrow(pred_days))) {
      day_data = pred_days[i, ]
      
      # Extract key variables, handling nested structures
      forecast_row = data.frame(
        municipio_id = municipio_code,
        municipio_nombre = municipio_nombre,
        provincia = municipio_provincia,
        elaborado = elaborado,
        fecha = day_data$fecha,
        stringsAsFactors = FALSE
      )
      
      # Temperature variables - using direct access from flattened data
      forecast_row$temperatura_maxima = if("temperatura.maxima" %in% names(day_data)) day_data$temperatura.maxima else NA
      forecast_row$temperatura_minima = if("temperatura.minima" %in% names(day_data)) day_data$temperatura.minima else NA
      forecast_row$temperatura_dato = if("temperatura.dato" %in% names(day_data)) day_data$temperatura.dato else NA
      
      # Humidity variables - using direct access from flattened data
      forecast_row$humedad_maxima = if("humedadRelativa.maxima" %in% names(day_data)) day_data$humedadRelativa.maxima else NA
      forecast_row$humedad_minima = if("humedadRelativa.minima" %in% names(day_data)) day_data$humedadRelativa.minima else NA
      forecast_row$humedad_dato = if("humedadRelativa.dato" %in% names(day_data)) day_data$humedadRelativa.dato else NA
      
      # Precipitation probability
      if("probPrecipitacion" %in% names(day_data)) {
        # Handle list of periods or single value
        prob_prec = day_data$probPrecipitacion[[1]]
        if(is.list(prob_prec) && length(prob_prec) > 0) {
          # Take maximum probability across periods
          forecast_row$prob_precipitacion = max(sapply(prob_prec, function(x) as.numeric(x$value)), na.rm = TRUE)
        } else {
          forecast_row$prob_precipitacion = NA
        }
      } else {
        forecast_row$prob_precipitacion = NA
      }
      
      # Wind gust maximum
      if("rachaMax" %in% names(day_data)) {
        racha_data = day_data$rachaMax[[1]]
        if(is.list(racha_data) && length(racha_data) > 0) {
          # Take maximum gust across periods
          forecast_row$racha_max = max(sapply(racha_data, function(x) as.numeric(x$value)), na.rm = TRUE)
        } else {
          forecast_row$racha_max = NA
        }
      } else {
        forecast_row$racha_max = NA
      }
      
      # UV index
      if("uvMax" %in% names(day_data) && !is.null(day_data$uvMax)) {
        forecast_row$uv_max = as.numeric(day_data$uvMax)
      } else {
        forecast_row$uv_max = NA
      }
      
      forecast_list[[i]] = forecast_row
    }
    
    # Combine all days for this municipality
    municipality_forecast = do.call(rbind, forecast_list)
    return(municipality_forecast)
    
  }, error = function(e) {
    cat("Error processing municipality", municipio_code, ":", e$message, "\n")
    return(NULL)
  })
}

# Get list of major Spanish municipalities (sample for testing)
# Load complete municipality list from data file
cat("Loading municipality codes from data/municipalities.csv.gz...\n")
municipalities_data = fread("data/municipalities.csv.gz")
cat("Loaded", nrow(municipalities_data), "municipalities\n")

# Extract all municipality codes
all_municipality_codes = municipalities_data$CUMUN

# For testing/development, set SAMPLE_SIZE to limit municipalities
# Start with a small number to test API rate limits
SAMPLE_SIZE = 5  # Change this to NULL for all municipalities
DEBUG_MODE = FALSE  # Set to TRUE to see detailed API responses

if(!is.null(SAMPLE_SIZE) && SAMPLE_SIZE < length(all_municipality_codes)) {
  major_municipalities = as.character(head(all_municipality_codes, SAMPLE_SIZE))
  cat("Using sample of", SAMPLE_SIZE, "municipalities for testing\n")
} else {
  major_municipalities = as.character(all_municipality_codes)
  cat("Using all", length(major_municipalities), "municipalities\n")
}

cat("Starting forecast data collection for", length(major_municipalities), "municipalities...\n")

# Debug mode: analyze first municipality in detail
if(DEBUG_MODE && length(major_municipalities) > 0) {
  cat("\n=== RUNNING IN DEBUG MODE ===\n")
  cat("Testing with Madrid (28079) as a known-good municipality code...\n")
  debug_municipal_forecast("28079")
  cat("Now testing with first municipality from our sample:", major_municipalities[1], "\n")
  debug_municipal_forecast(major_municipalities[1])
  cat("Debug complete. Set DEBUG_MODE = FALSE to run normal collection.\n")
  quit(save = "no", status = 0)
}

# Collect forecasts for all municipalities
all_forecasts = list()
successful_count = 0

for(i in seq_along(major_municipalities)) {
  municipio = major_municipalities[i]
  
  # Progress tracking
  if(i %% 10 == 0 || i == 1) {
    cat("Processing municipality", i, "of", length(major_municipalities), 
        sprintf("(%.1f%% complete)", i/length(major_municipalities)*100), "\n")
  }
  
  forecast_data = get_municipal_forecast(municipio)
  
  if(!is.null(forecast_data)) {
    all_forecasts[[length(all_forecasts) + 1]] = forecast_data
    successful_count = successful_count + 1
  }
  
  # Be polite to the API - increased delay to handle rate limiting
  Sys.sleep(if(length(major_municipalities) > 100) 5 else 3)
}

if(length(all_forecasts) > 0) {
  # Combine all forecasts
  combined_forecasts = do.call(rbind, all_forecasts)
  
  # Convert to data.table and add collection timestamp
  forecast_dt = as.data.table(combined_forecasts)
  forecast_dt$collected_at = Sys.time()
  forecast_dt$fecha = as.Date(forecast_dt$fecha)
  
  # Load previous forecasts if they exist
  forecast_file = "data/spain_weather_municipal_forecast.csv.gz"
  if(file.exists(forecast_file)) {
    previous_forecasts = fread(forecast_file)
    
    # Remove old forecasts for the same collection time/municipality to avoid duplicates
    previous_forecasts = previous_forecasts[
      !(paste(municipio_id, as.Date(collected_at)) %in% 
        paste(forecast_dt$municipio_id, as.Date(forecast_dt$collected_at)))
    ]
    
    # Combine with new forecasts
    all_forecast_data = rbind(previous_forecasts, forecast_dt, fill = TRUE)
  } else {
    all_forecast_data = forecast_dt
    cat("Creating new municipal forecast dataset.\n")
  }
  
  # Sort by municipality and date
  all_forecast_data = all_forecast_data[order(municipio_id, fecha)]
  
  # Save updated forecasts
  fwrite(all_forecast_data, forecast_file)
  
  cat("Successfully collected forecasts for", successful_count, "municipalities.\n")
  cat("Total forecast records:", nrow(all_forecast_data), "\n")
  cat("Date range:", min(all_forecast_data$fecha), "to", max(all_forecast_data$fecha), "\n")
  
} else {
  cat("No forecast data collected. Check API connectivity and municipality codes.\n")
}

cat("Forecast collection completed.\n")
