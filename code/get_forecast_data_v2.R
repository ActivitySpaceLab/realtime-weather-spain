#!/usr/bin/env Rscript

# Simple forecast data collection based on proven working patterns
library(jsonlite)
library(httr)      # Use httr like in the working script
library(curl)
library(dplyr)
library(data.table)
library(lubridate)

# Load API keys
source("auth/keys.R")

cat("=== AEMET FORECAST DATA COLLECTION (SIMPLE v2) ===\n")
cat("Started at:", format(Sys.time()), "\n")

# Function to get municipality forecast using working pattern
get_municipality_forecast_v2 = function(municipio_code, municipio_name = NULL) {
  tryCatch({
    cat("Processing", municipio_code, "\n")
    
    # Initialize curl handle with current API key
    h = new_handle()
    handle_setheaders(h, 'api_key' = get_current_api_key())
    
    # Request forecast data URL
    response1 = curl_fetch_memory(
      paste0('https://opendata.aemet.es/opendata/api/prediccion/especifica/municipio/diaria/', municipio_code), 
      handle = h
    )
    
    if(response1$status_code == 429) {
      cat("Rate limit - rotating key...\n")
      rotate_api_key()
      handle_setheaders(h, 'api_key' = get_current_api_key())
      Sys.sleep(3)
      
      response1 = curl_fetch_memory(
        paste0('https://opendata.aemet.es/opendata/api/prediccion/especifica/municipio/diaria/', municipio_code), 
        handle = h
      )
    }
    
    if(response1$status_code != 200) {
      cat("API request failed:", response1$status_code, "\n")
      return(NULL)
    }
    
    # Parse response to get data URL
    response_content = fromJSON(rawToChar(response1$content))
    
    if(!"datos" %in% names(response_content)) {
      cat("No data URL in response\n")
      return(NULL)
    }
    
    # Fetch actual forecast data
    Sys.sleep(1)
    response2 = curl_fetch_memory(response_content$datos)
    
    if(response2$status_code != 200) {
      cat("Data request failed:", response2$status_code, "\n")
      return(NULL)
    }
    
    # Parse forecast data using your working approach
    this_string = rawToChar(response2$content)
    Encoding(this_string) = "latin1"
    forecast_data = fromJSON(this_string)
    
    # Extract municipality info
    municipio_nombre = forecast_data$nombre
    provincia = forecast_data$provincia
    elaborado = forecast_data$elaborado
    
    # Process all 7 days at once (wdia[[1]] contains vectors for all days)
            wdia = forecast_data$prediccion$dia
            
            # Extract vectors for all 7 days using your proven pattern
            fechas = as.Date(wdia[[1]]$fecha)  # Direct conversion using as.Date
            temp_max = wdia[[1]]$temperatura$maxima
            temp_min = wdia[[1]]$temperatura$minima
            temp_avg = rowMeans(cbind(temp_max, temp_min), na.rm = TRUE)
            
            # Extract additional variables following your pattern
            humid_max = if("humedadRelativa" %in% names(wdia[[1]])) {
              wdia[[1]]$humedadRelativa$maxima
            } else rep(NA, length(fechas))
            
            humid_min = if("humedadRelativa" %in% names(wdia[[1]])) {
              wdia[[1]]$humedadRelativa$minima
            } else rep(NA, length(fechas))
            
            # Wind data (following your unlist/lapply pattern)
            wind_speed = if("viento" %in% names(wdia[[1]])) {
              unlist(lapply(wdia[[1]]$viento, function(x) {
                if(is.list(x) && "velocidad" %in% names(x)) {
                  mean(x$velocidad, na.rm = TRUE)
                } else NA
              }))
            } else rep(NA, length(fechas))
            
            cat("Extracted", length(fechas), "forecast days\n")
            cat("First day - Date:", as.character(fechas[1]), "Temp max:", temp_max[1], "Temp min:", temp_min[1], "Temp avg:", temp_avg[1], "\n")
            
            # Create result data frame with all 7 days
            result = data.frame(
              municipio_id = municipio_code,
              municipio_nombre = forecast_data$nombre,
              provincia = forecast_data$provincia,
              elaborado = forecast_data$elaborado,
              fecha = fechas,
              temp_max = temp_max,
              temp_min = temp_min, 
              temp_avg = temp_avg,
              humid_max = humid_max,
              humid_min = humid_min,
              wind_speed = wind_speed,
              stringsAsFactors = FALSE
            )
            
            return(result)
    
  }, error = function(e) {
    cat("✗ ERROR:", e$message, "\n")
    return(NULL)
  })
}

# Load municipality data
cat("Loading municipality codes...\n")
municipalities_data = fread("data/municipalities.csv.gz")
cat("Loaded", nrow(municipalities_data), "municipalities\n")

# Use small sample for testing
SAMPLE_SIZE = 2
working_municipalities = head(municipalities_data$CUMUN, SAMPLE_SIZE)
names(working_municipalities) = head(municipalities_data$NAMEUNIT, SAMPLE_SIZE)

cat("Testing with", SAMPLE_SIZE, "municipalities\n\n")

# Collect forecasts
all_forecasts = list()
successful_collections = 0

for(i in seq_along(working_municipalities)) {
  city = names(working_municipalities)[i]
  code = working_municipalities[i]
  
  cat("Municipality", i, "of", length(working_municipalities), ":", city, "(", code, ")\n")
  
  if(i > 1) {
    cat("Waiting 15 seconds...\n")
    Sys.sleep(15)  # Longer delay to avoid rate limits
  }
  
  forecast_data = get_municipality_forecast_v2(code, city)
  
  if(!is.null(forecast_data)) {
    all_forecasts[[code]] = forecast_data
    successful_collections = successful_collections + 1
  }
  
  cat("\n")
}

cat("=== RESULTS ===\n")
cat("Municipalities attempted:", length(working_municipalities), "\n")
cat("Successful collections:", successful_collections, "\n")

if(length(all_forecasts) > 0) {
  final_data = do.call(rbind, all_forecasts)
  
  # Add collection timestamp
  final_data$collected_at = Sys.time()
  
  cat("Total forecast records:", nrow(final_data), "\n")
  cat("Date range:", as.character(min(final_data$fecha)), "to", as.character(max(final_data$fecha)), "\n")
  cat("Sample data:\n")
  print(head(final_data, 3))
  
  # Save the data
  output_file = paste0("data/spain_weather_forecast_", Sys.Date(), ".csv")
  write.csv(final_data, output_file, row.names = FALSE)
  cat("Data saved to:", output_file, "\n")
} else {
  cat("No data collected\n")
}

cat("Completed at:", format(Sys.time()), "\n")
