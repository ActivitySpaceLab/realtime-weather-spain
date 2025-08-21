#!/usr/bin/env Rscript

# get_forecast_data_simple.R
# --------------------------
# Purpose: Download 7-day municipal weather forecasts from AEMET OpenData API
# Simplified version with robust error handling and working municipality codes

library(curl)
library(jsonlite)
library(dplyr)
library(data.table)

# Load API key
source("auth/keys.R")

# If you want to prevent concurrent runs of this script, set PREVENT_CONCURRENT_RUNS to TRUE.
PREVENT_CONCURRENT_RUNS = FALSE

if(PREVENT_CONCURRENT_RUNS) {
  # Prevent concurrent runs by creating a lockfile
  lockfile <- "tmp/get_forecast_data.lock"
  if (file.exists(lockfile)) {
    cat("Another forecast run is in progress. Exiting.\n")
    quit(save = "no", status = 0)
  }
  dir.create("tmp", showWarnings = FALSE)
  file.create(lockfile)
  on.exit(unlink(lockfile), add = TRUE)
}

# Create curl handle
h <- new_handle()
handle_setheaders(h, 'api_key' = my_api_key)

cat("=== AEMET FORECAST DATA COLLECTION (SIMPLE) ===\n")
cat("Started at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# Function to safely get forecast for one municipality
get_municipality_forecast_simple = function(municipio_code, municipio_name = NULL, max_retries = 2) {
  
  for(attempt in 1:max_retries) {
    tryCatch({
      cat("Processing", municipio_code, "...")
      
      # Request forecast data URL
      req = curl_fetch_memory(
        paste0('https://opendata.aemet.es/opendata/api/prediccion/especifica/municipio/diaria/', municipio_code), 
        handle = h
      )
      
      if(req$status_code != 200) {
        cat(" API request failed (status", req$status_code, ")\n")
        return(NULL)
      }
      
      # Parse response to get data URL
      response_content = fromJSON(rawToChar(req$content))
      
      if(!"datos" %in% names(response_content)) {
        cat(" No data URL in response\n")
        return(NULL)
      }
      
      # Fetch actual forecast data
      Sys.sleep(0.5)  # Small delay to avoid rate limiting
      req2 = curl_fetch_memory(response_content$datos)
      
      if(req2$status_code != 200) {
        cat(" Data request failed (status", req2$status_code, ")\n")
        return(NULL)
      }
      
      # Parse forecast data with proper encoding
      this_string = rawToChar(req2$content)
      Encoding(this_string) = "latin1"
      forecast_data = fromJSON(this_string)
      
      # Extract basic municipality info
      municipio_nombre = forecast_data$nombre
      provincia = forecast_data$provincia
      elaborado = forecast_data$elaborado
      
      # Extract forecast days
      pred_days = forecast_data$prediccion$dia
      
      if(length(pred_days) == 0) {
        cat(" No forecast days\n")
        return(NULL)
      }
      
      # Process forecast days into simple format
      forecast_rows = list()
      
      for(i in seq_along(pred_days)) {
        day = pred_days[[i]]
        
        # Basic row structure
        row = data.frame(
          municipio_id = municipio_code,
          municipio_nombre = municipio_nombre,
          provincia = provincia,
          elaborado = elaborado,
          fecha = day$fecha,
          
          # Temperature - extract from potentially nested structure
          temp_max = if("temperatura" %in% names(day)) {
            temp = day$temperatura
            if(is.list(temp) && "maxima" %in% names(temp)) temp$maxima else NA
          } else NA,
          
          temp_min = if("temperatura" %in% names(day)) {
            temp = day$temperatura
            if(is.list(temp) && "minima" %in% names(temp)) temp$minima else NA
          } else NA,
          
          # Humidity - extract from potentially nested structure
          humid_max = if("humedadRelativa" %in% names(day)) {
            humid = day$humedadRelativa
            if(is.list(humid) && "maxima" %in% names(humid)) humid$maxima else NA
          } else NA,
          
          humid_min = if("humedadRelativa" %in% names(day)) {
            humid = day$humedadRelativa
            if(is.list(humid) && "minima" %in% names(humid)) humid$minima else NA
          } else NA,
          
          # Precipitation probability - simplified
          precip_prob = if("probPrecipitacion" %in% names(day)) {
            prob = day$probPrecipitacion
            if(is.list(prob) && length(prob) > 0) {
              # Take first non-null value or maximum
              values = sapply(prob, function(x) if("value" %in% names(x)) x$value else x)
              max(as.numeric(values), na.rm = TRUE)
            } else as.numeric(prob)
          } else NA,
          
          # UV index
          uv_max = if("uvMax" %in% names(day)) as.numeric(day$uvMax) else NA,
          
          stringsAsFactors = FALSE
        )
        
        forecast_rows[[i]] = row
      }
      
      # Combine all days for this municipality
      result = do.call(rbind, forecast_rows)
      cat(" SUCCESS (", nrow(result), "days )\n")
      return(result)
      
    }, error = function(e) {
      cat(" ERROR:", e$message, "\n")
      if(attempt < max_retries) {
        cat("  Retrying...\n")
        Sys.sleep(2)
      }
    })
  }
  
  cat(" FAILED after", max_retries, "attempts\n")
  return(NULL)
}

# Load complete municipality list from data file
cat("Loading municipality codes from data/municipalities.csv.gz...\n")
municipalities_data = fread("data/municipalities.csv.gz")
cat("Loaded", nrow(municipalities_data), "municipalities\n")

# For testing/development, set SAMPLE_SIZE to limit municipalities  
# Set to NULL for all municipalities, or a number for testing
SAMPLE_SIZE = 5  # Change this to NULL for all municipalities

if(!is.null(SAMPLE_SIZE) && SAMPLE_SIZE < nrow(municipalities_data)) {
  working_municipalities = head(municipalities_data$CUMUN, SAMPLE_SIZE)
  names(working_municipalities) = head(municipalities_data$NAMEUNIT, SAMPLE_SIZE)
  cat("Using sample of", SAMPLE_SIZE, "municipalities for testing\n")
} else {
  working_municipalities = municipalities_data$CUMUN
  names(working_municipalities) = municipalities_data$NAMEUNIT
  cat("Using all", length(working_municipalities), "municipalities\n")
}

# Convert to character for API calls
working_municipalities = as.character(working_municipalities)

cat("Collecting forecasts for", length(working_municipalities), "municipalities...\n\n")

# Collect forecasts
all_forecasts = list()
successful_collections = 0

for(city in names(working_municipalities)) {
  code = working_municipalities[[city]]
  forecast_data = get_municipality_forecast_simple(code, city)
  
  if(!is.null(forecast_data)) {
    all_forecasts[[code]] = forecast_data
    successful_collections = successful_collections + 1
  }
  
  # Rate limiting between requests
  Sys.sleep(1)
}

cat("\n=== FORECAST COLLECTION SUMMARY ===\n")
cat("Municipalities attempted:", length(working_municipalities), "\n")
cat("Successful collections:", successful_collections, "\n")

if(length(all_forecasts) > 0) {
  # Combine all forecast data
  final_forecast_data = do.call(rbind, all_forecasts)
  
  # Add processing timestamp
  final_forecast_data$collected_at = Sys.time()
  
  # Convert dates
  final_forecast_data$fecha = as.Date(final_forecast_data$fecha)
  final_forecast_data$elaborado = as.POSIXct(final_forecast_data$elaborado, format = "%Y-%m-%dT%H:%M:%S")
  
  # Sort by municipality and date
  final_forecast_data = final_forecast_data[order(final_forecast_data$municipio_id, final_forecast_data$fecha), ]
  
  cat("Total forecast records:", nrow(final_forecast_data), "\n")
  cat("Date range:", min(final_forecast_data$fecha), "to", max(final_forecast_data$fecha), "\n")
  cat("Variables:", paste(names(final_forecast_data), collapse = ", "), "\n")
  
  # Save to file
  if(!dir.exists("data")) dir.create("data")
  output_file = "data/spain_weather_forecasts.csv.gz"
  
  write.csv(final_forecast_data, gzfile(output_file), row.names = FALSE)
  
  cat("Forecast data saved to:", output_file, "\n")
  cat("File size:", round(file.size(output_file) / 1024, 1), "KB\n")
  
  # Show sample of data
  cat("\nSample forecast data:\n")
  print(head(final_forecast_data[, c("municipio_nombre", "fecha", "temp_max", "temp_min", "humid_max", "precip_prob")], 10))
  
} else {
  cat("No forecast data collected successfully\n")
}

cat("\nForecast collection completed at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
