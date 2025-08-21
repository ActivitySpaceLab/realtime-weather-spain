#!/usr/bin/env Rscript

# Detailed analysis of AEMET forecast data structure
# This script examines the forecast endpoints to understand available variables

# Load necessary libraries
suppressPackageStartupMessages({
  library(curl)
  library(jsonlite)
  library(dplyr)
})

# Load API key
source("auth/keys.R")

# Create curl handle
h = new_handle()
handle_setheaders(h, "api_key" = my_api_key)

# Test municipality (Madrid)
municipio_code = "28079"

cat("=== ANALYZING AEMET FORECAST DATA STRUCTURE ===\n\n")

# Test hourly forecast
cat("1. HOURLY FORECAST ANALYSIS\n")
cat("-----------------------------\n")

tryCatch({
  req = curl_fetch_memory(paste0('https://opendata.aemet.es/opendata/api/prediccion/especifica/municipio/horaria/', municipio_code), handle=h)
  
  if(req$status_code != 200) {
    cat("API request failed with status:", req$status_code, "\n")
  } else {
    response_content = fromJSON(rawToChar(req$content))
    
    if("datos" %in% names(response_content)) {
      # Get actual forecast data
      req2 = curl_fetch_memory(response_content$datos)
      
      if(req2$status_code == 200) {
        this_string = rawToChar(req2$content)
        Encoding(this_string) = "latin1"
        hourly_forecast = fromJSON(this_string, flatten = TRUE)
        
        cat("✓ Successfully retrieved hourly forecast data\n")
        cat("Municipality:", hourly_forecast$nombre, "\n")
        cat("Last updated:", hourly_forecast$elaborado, "\n\n")
        
        # Examine prediction structure
        pred_days = hourly_forecast$prediccion.dia[[1]]
        cat("Number of forecast days:", nrow(pred_days), "\n\n")
        
        # Analyze first day's hourly data
        first_day = pred_days[1, ]
        cat("Variables available for hourly forecasts:\n")
        
        # List all available variables for the first day
        hourly_vars = names(first_day)
        for(var in hourly_vars) {
          if(!is.null(first_day[[var]]) && length(first_day[[var]]) > 0) {
            if(is.list(first_day[[var]][[1]])) {
              n_hours = length(first_day[[var]][[1]])
              cat("  -", var, ":", n_hours, "hourly values\n")
              
              # Show structure of first few hours for key variables
              if(var %in% c("temperatura", "precipitacion", "vientoAndRachaMax", "humedadRelativa")) {
                cat("    Sample structure:", class(first_day[[var]][[1]]), "\n")
                if(n_hours > 0) {
                  sample_data = first_day[[var]][[1]][1:min(3, n_hours)]
                  if(var == "temperatura") {
                    cat("    Sample values (first 3 hours):\n")
                    for(i in 1:length(sample_data)) {
                      cat("      Hour", i, "- value:", sample_data[[i]]$value, "°C\n")
                    }
                  } else if(var == "precipitacion") {
                    cat("    Sample values (first 3 hours):\n")
                    for(i in 1:length(sample_data)) {
                      cat("      Hour", i, "- value:", sample_data[[i]]$value, "mm\n")
                    }
                  } else if(var == "vientoAndRachaMax") {
                    cat("    Sample values (first 3 hours):\n")
                    for(i in 1:length(sample_data)) {
                      cat("      Hour", i, "- direccion:", sample_data[[i]]$direccion, ", velocidad:", sample_data[[i]]$velocidad, "km/h\n")
                    }
                  }
                }
                cat("\n")
              }
            } else {
              cat("  -", var, ":", typeof(first_day[[var]]), "\n")
            }
          }
        }
        
      } else {
        cat("Forecast data request failed with status:", req2$status_code, "\n")
      }
    }
  }
}, error = function(e) {
  cat("Error in hourly forecast analysis:", e$message, "\n")
})

cat("\n\n2. DAILY FORECAST ANALYSIS\n")
cat("---------------------------\n")

tryCatch({
  req = curl_fetch_memory(paste0('https://opendata.aemet.es/opendata/api/prediccion/especifica/municipio/diaria/', municipio_code), handle=h)
  
  if(req$status_code != 200) {
    cat("API request failed with status:", req$status_code, "\n")
  } else {
    response_content = fromJSON(rawToChar(req$content))
    
    if("datos" %in% names(response_content)) {
      # Get actual forecast data
      req2 = curl_fetch_memory(response_content$datos)
      
      if(req2$status_code == 200) {
        this_string = rawToChar(req2$content)
        Encoding(this_string) = "latin1"
        daily_forecast = fromJSON(this_string, flatten = TRUE)
        
        cat("✓ Successfully retrieved daily forecast data\n")
        cat("Municipality:", daily_forecast$nombre, "\n")
        cat("Last updated:", daily_forecast$elaborado, "\n\n")
        
        # Examine prediction structure
        pred_days = daily_forecast$prediccion.dia[[1]]
        cat("Number of forecast days:", nrow(pred_days), "\n\n")
        
        cat("Variables available for daily forecasts:\n")
        daily_vars = names(pred_days)
        for(var in daily_vars) {
          cat("  -", var, "\n")
          
          # Show sample data for key variables
          if(var %in% c("temperatura", "precipitacion", "viento", "humedadRelativa") && !is.null(pred_days[[var]][1])) {
            sample_val = pred_days[[var]][1]
            if(is.list(sample_val[[1]])) {
              if(var == "temperatura") {
                temp_data = sample_val[[1]]
                if("maxima" %in% names(temp_data)) cat("    Max temp:", temp_data$maxima, "°C\n")
                if("minima" %in% names(temp_data)) cat("    Min temp:", temp_data$minima, "°C\n")
              } else if(var == "precipitacion") {
                precip_data = sample_val[[1]]
                if(length(precip_data) > 0) {
                  cat("    Precipitation periods:", length(precip_data), "\n")
                }
              }
            }
          }
        }
        
      } else {
        cat("Daily forecast data request failed with status:", req2$status_code, "\n")
      }
    }
  }
}, error = function(e) {
  cat("Error in daily forecast analysis:", e$message, "\n")
})

cat("\n\n=== SUMMARY ===\n")
cat("This analysis helps determine:\n")
cat("1. What forecast variables are available (hourly vs daily)\n") 
cat("2. How many days ahead forecasts are provided\n")
cat("3. The data structure for integrating forecasts into existing workflow\n")
cat("4. Compatibility with current observation variables\n")
