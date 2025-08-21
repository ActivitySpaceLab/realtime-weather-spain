# Variable Inspector for AEMET API
# This script fetches one API response and shows all available variables

rm(list=ls())

library(tidyverse)
library(curl)
library(jsonlite)

# Load API keys
source("auth/keys.R")

# Set up handle
h <- new_handle()
handle_setheaders(h, 'api_key' = my_api_key)

# Fetch one sample to inspect variables
cat("Fetching sample data to inspect variables...\n")

tryCatch({
  req = curl_fetch_memory(paste0('https://opendata.aemet.es/opendata/api/observacion/convencional/todas'), handle=h)
  
  # Check if request was successful
  if(req$status_code != 200) {
    cat("API request failed with status:", req$status_code, "\n")
    cat("Response:", rawToChar(req$content), "\n")
    quit()
  }
  
  response_content = fromJSON(rawToChar(req$content))
  cat("API response keys:", names(response_content), "\n")
  
  if("datos" %in% names(response_content)) {
    wurl = response_content$datos
    cat("Data URL received, fetching actual data...\n")
    
    req2 = curl_fetch_memory(wurl)
    if(req2$status_code != 200) {
      cat("Data request failed with status:", req2$status_code, "\n")
      quit()
    }
    
    this_string = rawToChar(req2$content)
    Encoding(this_string) = "latin1"
    wdia = fromJSON(this_string) %>% as_tibble()
    
    cat("SUCCESS! Data retrieved.\n")
    cat("Number of variables:", ncol(wdia), "\n")
    cat("Number of observations:", nrow(wdia), "\n\n")
    
    cat("Variable names:\n")
    print(colnames(wdia))
    
    cat("\nSample of first few rows:\n")
    print(head(wdia, 3))
    
    # Show data types
    cat("\nData structure:\n")
    str(wdia)
    
    # Look for any variables with all NA values
    cat("\nVariables with percentage of non-NA values:\n")
    na_summary <- wdia %>%
      summarise_all(~round((sum(!is.na(.)) / length(.)) * 100, 1)) %>%
      gather(variable, pct_non_na) %>%
      arrange(desc(pct_non_na))
    
    print(na_summary)
    
  } else {
    cat("No 'datos' field in API response\n")
    print(response_content)
  }
  
}, error = function(e) {
  cat("Error occurred:", e$message, "\n")
  cat("This might be due to API rate limits, network issues, or invalid API key\n")
})
