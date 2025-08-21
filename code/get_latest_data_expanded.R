# get_latest_data_expanded.R
# ----------------------
# Purpose: Download and update the latest observation data from AEMET stations across Spain.
#
# This script fetches weather observations from the AEMET OpenData API using the 7 core variables
# that are compatible across current observations, historical data, and forecast endpoints.
#
# Core Variables (Safe for all endpoints):
#   - ta: Air temperature (°C)
#   - tamax: Maximum temperature (°C) 
#   - tamin: Minimum temperature (°C)
#   - hr: Relative humidity (%)
#   - prec: Precipitation (mm)
#   - vv: Wind speed (km/h)
#   - pres: Atmospheric pressure (hPa)
#
# Main Steps:
#   1. Load dependencies and API key.
#   2. Define functions to request and process data from the AEMET API, with error handling and retries.
#   3. Download the latest data and reshape it for storage.
#   4. Append new data to the local CSV file, ensuring no duplicates.
#
# Usage:
#   - Requires a valid API key in 'auth/keys.R' as 'my_api_key'.
#   - Run as an R script. Output is written to 'data/spain_weather_expanded.csv.gz'.
#
# Dependencies: tidyverse, lubridate, curl, jsonlite, data.table, R.utils
#
# Author: John Palmer
# Date: 2025-08-20 (Updated for 7-variable expansion)

# Title ####
# For downloading latest observation data from AEMET stations all over Spain. This needs to be run at least every 12 hours, but better to run it every 2 because of API limits, failures etc.

rm(list=ls())


# Dependencies ####
library(tidyverse)
library(lubridate)
library(curl)
library(jsonlite)
library(data.table)
library(R.utils)

# Set locale to UTF-8 for proper encoding handling
Sys.setlocale("LC_ALL", "en_US.UTF-8")

# If you want to prevent concurrent runs of this script, set PREVENT_CONCURRENT_RUNS to TRUE.
PREVENT_CONCURRENT_RUNS = FALSE

if(PREVENT_CONCURRENT_RUNS) {
  # Prevent concurrent runs by creating a lockfile
  # Lockfile management
  lockfile <- "tmp/get_latest_data_expanded.lock"
  # Check if lockfile exists
  if (file.exists(lockfile)) {
    cat("Another run is in progress. Exiting.\n")
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

# aemet_api_request: Fetches latest weather observation data from AEMET API and returns as tibble.
# Only selects the 7 core variables that are compatible across all endpoints.
aemet_api_request = function(){
  req = curl_fetch_memory(paste0('https://opendata.aemet.es/opendata/api/observacion/convencional/todas'), handle=h)
  wurl = fromJSON(rawToChar(req$content))$datos
  req = curl_fetch_memory(wurl)
  this_string = rawToChar(req$content)
  Encoding(this_string) = "latin1"
  wdia  = fromJSON(this_string) %>% 
    as_tibble() %>%
    dplyr::select(fint, idema, ta, tamax, tamin, hr, prec, vv, pres)
  return(wdia)
}

# get_data: Wrapper for aemet_api_request with error handling and retry logic.
get_data = function(){
  tryCatch(
    expr = {
     return(aemet_api_request())
    },
    error = function(e){ 
      # (Optional)
      # Do this if an error is caught...
      print(e)
      # waiting and then...
      Sys.sleep(50)
      # try again:
      wdia = get_data()
      return(NULL)
    },
    warning = function(w){
      print(w)
      # (Optional)
      # Do this if a warning is caught...
      return(NULL)
    },
    finally = {
      # (Optional)
      # Do this at the end before quitting the tryCatch structure...
    }
  )
}

# Ensure data directory exists
if(!dir.exists("data")) {
  dir.create("data")
}

# Set up cURL handle with API key
h <- new_handle()
handle_setheaders(h, 'api_key' = my_api_key)

# Download latest data with retry logic
wdia = get_data()
if(is.null(wdia)){
  # If data retrieval failed, wait and try again
  Sys.sleep(60)
  wdia = get_data()
}

# If data was successfully retrieved, process and save
if(!is.null(wdia) && nrow(wdia) > 0){
  # Reshape and clean latest weather data - use all 7 core variables
  latest_weather = wdia %>% 
    pivot_longer(cols = c(ta, tamax, tamin, hr, prec, vv, pres), 
                 names_to = "measure", 
                 values_to = "value") %>% 
    filter(!is.na(value)) %>% 
    mutate(fint = as_datetime(fint)) %>% 
    as.data.table()

  print(paste0("Downloaded ", nrow(latest_weather), " new rows of data with 7 core variables."))

  # Load previous weather data
  if(file.exists("data/spain_weather_expanded.csv.gz")) {
    previous_weather = fread("data/spain_weather_expanded.csv.gz")
  } else {
    previous_weather = data.table()
    print("Creating new expanded weather dataset file.")
  }

  # Combine and deduplicate
  spain_weather = bind_rows(latest_weather, previous_weather) %>% 
    distinct() %>%
    arrange(desc(fint))

  # Save updated data
  fwrite(as.data.table(spain_weather), "data/spain_weather_expanded.csv.gz")
  
  print(paste0("Total dataset now contains ", nrow(spain_weather), " rows."))
} else{
  print("No new data retrieved. Nothing saved.")
}


