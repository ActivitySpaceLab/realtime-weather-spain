# test_historical_variables.R
# Check what variables are available in historical daily climatological data

rm(list=ls())

library(tidyverse)
library(lubridate)
library(curl)
library(jsonlite)

source("auth/keys.R")

h <- new_handle()
handle_setheaders(h, 'api_key' = my_api_key)

# Test historical daily endpoint with recent date
test_date = today() - 5
cat("Testing historical endpoint for date:", as.character(test_date), "\n")

tryCatch({
  # Historical daily climatological data endpoint
  req = curl_fetch_memory(paste0('https://opendata.aemet.es/opendata/api/valores/climatologicos/diarios/datos/fechaini/', test_date, 'T00%3A00%3A00UTC/fechafin/', test_date, 'T23%3A59%3A59UTC/todasestaciones'), handle=h)
  
  if(req$status_code != 200) {
    cat("Historical API request failed with status:", req$status_code, "\n")
    cat("Response:", rawToChar(req$content), "\n")
  } else {
    response_content = fromJSON(rawToChar(req$content))
    wurl = response_content$datos
    
    req2 = curl_fetch_memory(wurl)
    if(req2$status_code != 200) {
      cat("Historical data request failed with status:", req2$status_code, "\n")
    } else {
      this_string = rawToChar(req2$content)
      Encoding(this_string) = "latin1"
      wdia = fromJSON(this_string) %>% as_tibble()
      
      cat("SUCCESS! Historical data retrieved.\n")
      cat("Number of variables:", ncol(wdia), "\n")
      cat("Number of observations:", nrow(wdia), "\n\n")
      
      cat("Historical variable names:\n")
      print(colnames(wdia))
      
      cat("\nSample of first few rows:\n")
      print(head(wdia, 3))
      
      # Show data coverage
      cat("\nHistorical variables with percentage of non-NA values:\n")
      na_summary <- wdia %>%
        summarise_all(~round((sum(!is.na(.)) / length(.)) * 100, 1)) %>%
        gather(variable, pct_non_na) %>%
        arrange(desc(pct_non_na))
      
      print(na_summary)
    }
  }
}, error = function(e) {
  cat("Error occurred:", e$message, "\n")
})
