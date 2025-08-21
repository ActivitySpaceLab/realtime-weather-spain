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

# Create curl handle with initial API key
h <- new_handle()
handle_setheaders(h, 'api_key' = my_api_key)

# Function to update curl handle with current API key
update_curl_handle <- function() {
  current_key <- get_current_api_key()
  handle_setheaders(h, 'api_key' = current_key)
}

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

cat("=== AEMET FORECAST DATA COLLECTION (SIMPLE) ===\n")
cat("Started at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# Function to safely get forecast for one municipality
get_municipality_forecast_simple = function(municipio_code, municipio_name = NULL, max_retries = 2) {
  
  for(attempt in 1:max_retries) {
    tryCatch({
      cat("Processing", municipio_code, "- Attempt", attempt, "\n")
      
      # Create the full URL
      forecast_url = paste0('https://opendata.aemet.es/opendata/api/prediccion/especifica/municipio/diaria/', municipio_code)
      cat("Requesting URL:", forecast_url, "\n")
      cat("Using API key:", names(get_current_api_key()), "\n")
      
      # Request forecast data URL
      req = curl_fetch_memory(forecast_url, handle = h)
      cat("API request status:", req$status_code, "\n")
      
      if(req$status_code == 429) {
        cat("Rate limit hit - rotating API key...\n")
        rotate_api_key()
        update_curl_handle()
        Sys.sleep(5)  # Wait longer after key rotation
        
        # Retry with new key
        req = curl_fetch_memory(forecast_url, handle = h)
        cat("Retry request status:", req$status_code, "\n")
      }
      
      if(req$status_code != 200) {
        cat("API request failed with status", req$status_code, "\n")
        if(req$status_code == 401) cat("Authentication failed - check API key\n")
        if(req$status_code == 404) cat("Municipality code not found\n")
        if(req$status_code >= 500) cat("Server error - AEMET API may be down\n")
        next  # Try next attempt
      }
      
      # Parse response to get data URL
      response_content = fromJSON(rawToChar(req$content))
      cat("Response content names:", paste(names(response_content), collapse = ", "), "\n")
      
      if(!"datos" %in% names(response_content)) {
        cat("No data URL in response\n")
        next  # Try next attempt
      }
      
      cat("Data URL received, fetching forecast data...\n")
      
      # Fetch actual forecast data
      Sys.sleep(2)  # Longer delay to avoid rate limiting
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
      
      # Process forecast days into simple format using working approach
      forecast_rows = list()
      
      for(i in seq_along(pred_days)) {
        day = pred_days[[i]]
        
        # Use your working pattern for extracting values
        tryCatch({
          # Temperature - use your working approach
          temp_max = if("temperatura" %in% names(day) && !is.null(day$temperatura) && "maxima" %in% names(day$temperatura)) {
            val = day$temperatura$maxima
            if(length(val) == 1) as.numeric(val) else NA
          } else NA
          
          temp_min = if("temperatura" %in% names(day) && !is.null(day$temperatura) && "minima" %in% names(day$temperatura)) {
            val = day$temperatura$minima
            if(length(val) == 1) as.numeric(val) else NA
          } else NA
          
          # Temperature mean like your code
          temp_mean = if(!is.na(temp_max) && !is.na(temp_min)) {
            mean(c(temp_max, temp_min), na.rm = TRUE)
          } else NA
          
          # Wind velocity - using your unlist/lapply approach
          wind_speed = if("viento" %in% names(day) && length(day$viento) > 0) {
            tryCatch({
              velocidades = unlist(lapply(day$viento, function(x) {
                if(is.list(x) && "velocidad" %in% names(x)) x$velocidad else NA
              }))
              mean(velocidades, na.rm = TRUE)
            }, error = function(e) NA)
          } else NA
          
          # Humidity - simplified extraction
          humid_max = if("humedadRelativa" %in% names(day) && !is.null(day$humedadRelativa) && "maxima" %in% names(day$humedadRelativa)) {
            val = day$humedadRelativa$maxima
            if(length(val) == 1) as.numeric(val) else NA
          } else NA
          
          humid_min = if("humedadRelativa" %in% names(day) && !is.null(day$humedadRelativa) && "minima" %in% names(day$humedadRelativa)) {
            val = day$humedadRelativa$minima
            if(length(val) == 1) as.numeric(val) else NA
          } else NA
          
          # Basic row structure
          row = data.frame(
            municipio_id = municipio_code,
            municipio_nombre = municipio_nombre,
            provincia = provincia,
            elaborado = elaborado,
            fecha = as.Date(day$fecha),
            temp_max = temp_max,
            temp_min = temp_min,
            temp_mean = temp_mean,
            humid_max = humid_max,
            humid_min = humid_min,
            wind_speed = wind_speed,
            
            # Precipitation probability - simplified
            precip_prob = if("probPrecipitacion" %in% names(day)) {
              prob = day$probPrecipitacion
              if(is.list(prob) && length(prob) > 0) {
                # Take first available probability value
                first_prob = prob[[1]]
                if(is.numeric(first_prob)) first_prob else NA
              } else if(is.numeric(prob)) prob else NA
            } else NA,
            
            # UV index
            uv_max = if("uvMax" %in% names(day)) as.numeric(day$uvMax) else NA,
            
            stringsAsFactors = FALSE
          )
          
          forecast_rows[[i]] = row
          
        }, error = function(e) {
          cat("Error processing day", i, ":", e$message, "\n")
          # Create minimal row on error
          forecast_rows[[i]] = data.frame(
            municipio_id = municipio_code,
            municipio_nombre = municipio_nombre,
            provincia = provincia,
            elaborado = elaborado,
            fecha = if(exists("day") && "fecha" %in% names(day)) as.Date(day$fecha) else as.Date(Sys.time()),
            temp_max = NA, temp_min = NA, temp_mean = NA,
            humid_max = NA, humid_min = NA, wind_speed = NA,
            precip_prob = NA, uv_max = NA,
            stringsAsFactors = FALSE
          )
        })
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
# Start with a very small number due to API rate limiting issues
SAMPLE_SIZE = 2  # Start even smaller due to server issues

if(!is.null(SAMPLE_SIZE) && SAMPLE_SIZE < nrow(municipalities_data)) {
  working_municipalities = head(municipalities_data$CUMUN, SAMPLE_SIZE)
  names(working_municipalities) = head(municipalities_data$NAMEUNIT, SAMPLE_SIZE)
  cat("Using sample of", SAMPLE_SIZE, "municipalities for testing\n")
} else {
  working_municipalities = municipalities_data$CUMUN
  names(working_municipalities) = municipalities_data$NAMEUNIT
  cat("Using all", length(working_municipalities), "municipalities\n")
}

# Convert to character for API calls (preserve names)
municipality_names = names(working_municipalities)
working_municipalities = as.character(working_municipalities)
names(working_municipalities) = municipality_names

cat("Collecting forecasts for", length(working_municipalities), "municipalities...\n")
cat("First municipality codes:", head(working_municipalities, 2), "\n")
cat("First municipality names:", head(names(working_municipalities), 2), "\n\n")

# Collect forecasts
all_forecasts = list()
successful_collections = 0
municipality_count = 0

for(city in names(working_municipalities)) {
  municipality_count = municipality_count + 1
  code = working_municipalities[[city]]
  
  cat("Processing municipality", municipality_count, "of", length(working_municipalities), "\n")
  cat("Municipality:", city, "(", code, ")\n")
  
  # Add much longer delay between municipalities (except for first)
  if (municipality_count > 1) {
    cat("Waiting 10 seconds before next municipality...\n")
    Sys.sleep(10)
  }
  
  forecast_data = get_municipality_forecast_simple(code, city)
  
  if(!is.null(forecast_data)) {
    all_forecasts[[code]] = forecast_data
    successful_collections = successful_collections + 1
    cat("✓ Success - collected forecast data\n")
  } else {
    cat("✗ Failed to collect data\n")
  }
  
  cat("\n")
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
