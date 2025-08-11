# get_latest_data.R
# ----------------------
# Purpose: Download and update the latest observation data from AEMET stations across Spain.
#
# This script fetches the most recent weather observations from the AEMET OpenData API and appends them to the local dataset.
# It is recommended to run this script every 2 hours (at least every 12 hours) to minimize data loss due to API limits or failures.
#
# Main Steps:
#   1. Load dependencies and API key.
#   2. Define functions to request and process data from the AEMET API, with error handling and retries.
#   3. Download the latest data and reshape it for storage.
#   4. Append new data to the local CSV file, ensuring no duplicates.
#
# Usage:
#   - Requires a valid API key in 'auth/keys.R' as 'my_api_key'.
#   - Run as an R script. Output is written to 'data/spain_weather.csv.gz'.
#
# Dependencies: tidyverse, lubridate, curl, jsonlite, RSocrata, data.table, R.utils
#
# Author: John Palmer
# Date: 2025-07-21

# Title ####
# For downloading latest observation data from AEMET stations all over Spain. This needs to be run at least every 12 hours, but better to run it every 2 because of API limits, failures etc.

rm(list=ls())

####Dependencies####
library(tidyverse)
library(lubridate)
library(curl)
library(jsonlite)
library(RSocrata)
library(data.table)
library(R.utils)

source("auth/keys.R")

# aemet_api_request: Fetches latest weather observation data from AEMET API and returns as tibble.
aemet_api_request = function(){
  req = curl_fetch_memory(paste0('https://opendata.aemet.es/opendata/api/observacion/convencional/todas'), handle=h)
  wurl = fromJSON(rawToChar(req$content))$datos
  req = curl_fetch_memory(wurl)
  this_string = rawToChar(req$content)
  Encoding(this_string) = "latin1"
  wdia  = fromJSON(this_string) %>% as_tibble() %>% dplyr::select(fint, idema, tamax, tamin, hr)
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
if(!is.null(wdia) || nrow(wdia) > 0){
  # Reshape and clean latest weather data
  latest_weather = wdia %>% pivot_longer(cols = c(tamax, tamin, hr), names_to = "measure") %>% filter(!is.na(value)) %>% mutate(fint = as_datetime(fint)) %>% as.data.table()

  print(paste0("downloaded ", nrow(latest_weather), " new rows of data."))

  # Load previous weather data
  previous_weather = fread("data/spain_weather.csv.gz")

  # Combine and deduplicate
  spain_weather = bind_rows(latest_weather, previous_weather) %>% distinct()

  # Save updated data
  fwrite(as.data.table(spain_weather), "data/spain_weather.csv.gz")
} else{
  print("No new data. Nothing new saved")
}


