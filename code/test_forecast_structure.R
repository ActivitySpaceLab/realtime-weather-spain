#!/usr/bin/env Rscript

# Test script to examine forecast data structure
library(jsonlite)
library(curl)
library(dplyr)
library(data.table)

# Load API keys
source("auth/keys.R")

# Setup
cat("=== AEMET FORECAST STRUCTURE TEST ===\n")

# Initialize curl handle  
h = new_handle()
handle_setheaders(h, 'api_key' = get_current_api_key())

# Test with one municipality
municipio_code = "39084"  # Solórzano

cat("Testing municipality:", municipio_code, "\n")

# Get forecast URL
req = curl_fetch_memory(
  paste0('https://opendata.aemet.es/opendata/api/prediccion/especifica/municipio/diaria/', municipio_code), 
  handle = h
)

if(req$status_code != 200) {
  cat("API request failed:", req$status_code, "\n")
  quit()
}

# Parse response to get data URL
response_content = fromJSON(rawToChar(req$content))
cat("Response fields:", paste(names(response_content), collapse = ", "), "\n")

if(!"datos" %in% names(response_content)) {
  cat("No data URL in response\n")
  quit()
}

# Fetch actual forecast data
Sys.sleep(1)
req2 = curl_fetch_memory(response_content$datos)

if(req2$status_code != 200) {
  cat("Data request failed:", req2$status_code, "\n")
  quit()
}

# Parse forecast data
this_string = rawToChar(req2$content)
Encoding(this_string) = "latin1"
forecast_data = fromJSON(this_string)

cat("=== FORECAST DATA STRUCTURE ===\n")
cat("Top level fields:", paste(names(forecast_data), collapse = ", "), "\n")

if("prediccion" %in% names(forecast_data)) {
  pred = forecast_data$prediccion
  cat("Prediccion fields:", paste(names(pred), collapse = ", "), "\n")
  
  if("dia" %in% names(pred)) {
    dias = pred$dia
    cat("Number of forecast days:", length(dias), "\n")
    
    if(length(dias) > 0) {
      first_day = dias[[1]]
      cat("First day fields:", paste(names(first_day), collapse = ", "), "\n")
      
      # Check temperature structure
      if("temperatura" %in% names(first_day)) {
        temp = first_day$temperatura
        cat("Temperature type:", class(temp), "\n")
        cat("Temperature structure:\n")
        str(temp)
      }
      
      # Check humidity structure  
      if("humedadRelativa" %in% names(first_day)) {
        humid = first_day$humedadRelativa
        cat("Humidity type:", class(humid), "\n")
        cat("Humidity structure:\n")
        str(humid)
      }
      
      # Check precipitation structure
      if("probPrecipitacion" %in% names(first_day)) {
        precip = first_day$probPrecipitacion
        cat("Precipitation type:", class(precip), "\n")
        cat("Precipitation structure:\n")
        str(precip)
      }
    }
  }
}

cat("=== TEST COMPLETE ===\n")
