# get_historical_data_expanded.R
# ----------------------
# Purpose: Download and update historical daily weather data for Spain from the AEMET OpenData API.
#
# This script checks for missing dates in the local historical weather dataset and downloads any missing data in chunks.
# Data is fetched from the AEMET API, processed, and appended to the local CSV file.
#
# Concurrency Control:
#   - Set PREVENT_CONCURRENT_RUNS = TRUE to enable lockfile-based run prevention
#   - Set PREVENT_CONCURRENT_RUNS = FALSE (default) to allow multiple concurrent runs
#
# Main Steps:
#   1. Load dependencies and API key.
#   2. Determine which dates are missing from the local dataset.
#   3. Download missing data in chunks, handling API rate limits and errors.
#   4. Append new data to the historical dataset.
#
# Usage:
#   - Requires a valid API key in 'auth/keys.R' as 'my_api_key'.
#   - Run as an R script. Output is written to 'data/spain_weather_daily_historical.csv.gz'.
#
# Dependencies: tidyverse, lubridate, data.table, curl, jsonlite, RSocrata
#
# Author: [Your Name]
# Date: [YYYY-MM-DD]

# Title ####
# For downloading and preparing historical weather data. 

rm(list=ls())

####Dependencies####
library(tidyverse)
library(lubridate)
library(data.table)
library(curl)
library(jsonlite)
library(RSocrata)

# If you want to prevent concurrent runs of this script, set PREVENT_CONCURRENT_RUNS to TRUE.
PREVENT_CONCURRENT_RUNS = FALSE

if(PREVENT_CONCURRENT_RUNS) {
  # Prevent concurrent runs by creating a lockfile
  # Lockfile management
  lockfile <- "tmp/get_historical_data_expanded.lock"
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

# SETTING DATES ####
# Set the start date for historical data collection
start_date = as_date("2013-07-01")

# Set up curl handle with API key for authentication
h <- new_handle()
handle_setheaders(h, 'api_key' = my_api_key)

# Generate sequence of all dates to check (from start_date to 4 days before today)
all_dates = seq.Date(from = start_date, to=today()-4, by = "day")

# Load existing historical weather data
stored_weather_daily = fread("data/spain_weather_daily_historical.csv.gz")

# Reverse date order (latest first)
all_dates = all_dates[length(all_dates):1]

# Identify which dates are missing from the local dataset
these_dates = all_dates[which(!all_dates %in% unique(stored_weather_daily$date))]

# Set chunk size for API requests (to avoid rate limits)
chunksize = 20

# Main download loop: only run if there are missing dates
if(length(these_dates) > 0){

lapply(seq(1, length(these_dates), chunksize), function(j){
  
  this_chunk = these_dates[j:min(length(these_dates), (j+(chunksize-1)))]
  
  weather_daily = rbindlist(lapply(1:length(this_chunk), function(i){
    
    start_date = this_chunk[i]
    print(start_date)
    
    tryCatch(
      expr = {
        req = curl_fetch_memory(paste0('https://opendata.aemet.es/opendata/api/valores/climatologicos/diarios/datos/fechaini/', start_date, 'T00%3A00%3A00UTC/fechafin/', start_date, 'T23%3A59%3A59UTC/todasestaciones'), handle=h)
        
        wurl = fromJSON(rawToChar(req$content))$datos
        
        req = curl_fetch_memory(wurl)
        this_string = rawToChar(req$content)
        
        Encoding(this_string) = "latin1"
        
        wdia  = fromJSON(this_string) %>% as_tibble() %>% select(date = fecha, indicativo, TX = tmax, TN = tmin, HRX= hrMax, HRN = hrMin) %>% mutate(date = as_date(date),
          TX = as.numeric(str_replace(TX, ",", ".")),
          TN = as.numeric(str_replace(TN, ",", ".")),
          HRX = as.numeric(str_replace(HRX, ",", ".")),
          HRN = as.numeric(str_replace(HRN, ",", ".")) 
        ) %>% as.data.table()
        return(wdia)
        
      },
      error = function(e){ 
        # (Optional)
        # Do this if an error is caught...
        print(e)
        Sys.sleep(50)
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
    
  }))
  
  stored_weather_daily = fread("data/spain_weather_daily_historical_expanded.csv.gz")
  
#  stored_weather_daily =  stored_weather_daily %>% mutate(date = as_date(date), HRX = as.numeric(HRX), HRN = as.numeric(HRN))
  
  weather_daily = rbindlist(list(weather_daily, stored_weather_daily))
  
  print("writing chunk")
  
  fwrite(weather_daily, "data/spain_weather_daily_historical_expanded.csv.gz")
  
  print("pausing 30 seconds")
  Sys.sleep(30)
  
})

} else{
  
  print("Up to date - no historical data downloaded")
}

