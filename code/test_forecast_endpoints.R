# test_forecast_endpoints.R
# Test forecast endpoints for hourly predictions

rm(list=ls())

library(tidyverse)
library(lubridate)
library(curl)
library(jsonlite)

source("auth/keys.R")

h <- new_handle()
handle_setheaders(h, 'api_key' = my_api_key)

# Test municipal hourly forecast (need a municipality code)
# Barcelona municipality code: 08019
# Madrid: 28079
municipio_code = "28079" # Madrid

cat("Testing municipal hourly forecast for municipality:", municipio_code, "\n")

tryCatch({
  # Municipal hourly forecast endpoint
  req = curl_fetch_memory(paste0('https://opendata.aemet.es/opendata/api/prediccion/especifica/municipio/horaria/', municipio_code), handle=h)
  
  if(req$status_code != 200) {
    cat("Forecast API request failed with status:", req$status_code, "\n")
    cat("Response:", rawToChar(req$content), "\n")
  } else {
    response_content = fromJSON(rawToChar(req$content))
    cat("Forecast API response keys:", names(response_content), "\n")
    
    if("datos" %in% names(response_content)) {
      wurl = response_content$datos
      
      req2 = curl_fetch_memory(wurl)
      if(req2$status_code != 200) {
        cat("Forecast data request failed with status:", req2$status_code, "\n")
      } else {
        this_string = rawToChar(req2$content)
        Encoding(this_string) = "latin1"  # Changed from UTF-8 to latin1
        forecast_data = fromJSON(this_string, flatten = TRUE)
        
        cat("SUCCESS! Forecast data retrieved.\n")
        cat("Forecast data structure:\n")
        print(str(forecast_data, max.level = 2))
        
        # Check if it's a list with hourly data
        if(is.list(forecast_data) && length(forecast_data) > 0) {
          first_item = forecast_data[[1]]
          if("prediccion" %in% names(first_item)) {
            pred = first_item$prediccion
            if("dia" %in% names(pred)) {
              cat("\nForecast days available:", length(pred$dia), "\n")
              if(length(pred$dia) > 0) {
                first_day = pred$dia[[1]]
                cat("Variables in first forecast day:\n")
                print(names(first_day))
                
                # Check for hourly data
                if("temperatura" %in% names(first_day)) {
                  cat("\nTemperature forecast structure:\n")
                  print(str(first_day$temperatura, max.level = 2))
                }
              }
            }
          }
        }
      }
    }
  }
}, error = function(e) {
  cat("Error occurred:", e$message, "\n")
})

# Also test municipal daily forecast
cat("\n\n=== Testing Municipal Daily Forecast ===\n")
tryCatch({
  req = curl_fetch_memory(paste0('https://opendata.aemet.es/opendata/api/prediccion/especifica/municipio/diaria/', municipio_code), handle=h)
  
  if(req$status_code == 200) {
    response_content = fromJSON(rawToChar(req$content))
    if("datos" %in% names(response_content)) {
      wurl = response_content$datos
      req2 = curl_fetch_memory(wurl)
      if(req2$status_code == 200) {
        this_string = rawToChar(req2$content)
        Encoding(this_string) = "latin1"  # Fixed encoding
        daily_forecast = fromJSON(this_string, flatten = TRUE)
        cat("Daily forecast data structure:\n")
        print(str(daily_forecast, max.level = 2))
      }
    }
  }
}, error = function(e) {
  cat("Daily forecast error:", e$message, "\n")
})
