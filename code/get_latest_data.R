# Title ####
# For downloading latest observation data from AEMET stations all over Spain. This needs to be run at least every 12 hours, but better to run it every 2 because of API limits, failures etc.

rm(list=ls())

####Dependencies####
library(tidyverse)
library(lubridate)
library(curl)
library(jsonlite)
library(RSocrata)

source("auth/keys.R")

aemet_api_request = function(){
  req = curl_fetch_memory(paste0('https://opendata.aemet.es/opendata/api/observacion/convencional/todas'), handle=h)
  wurl = fromJSON(rawToChar(req$content))$datos
  req = curl_fetch_memory(wurl)
  this_string = rawToChar(req$content)
  Encoding(this_string) = "latin1"
  wdia  = fromJSON(this_string) %>% as_tibble() %>% dplyr::select(fint, idema, tamax, tamin, hr)
  return(wdia)
}

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

wdia = get_data()
if(is.null(wdia)){
  # we didn't get the data, wait in case the problem is that we are being throttled by the API...
  Sys.sleep(60)
  # then try again:
  wdia = get_data()
}

latest_weather = wdia %>% pivot_longer(cols = c(tamax, tamin, hr), names_to = "measure") %>% filter(!is.na(value))

previous_weather = read_rds("data/spain_weather.Rds")

spain_weather = bind_rows(latest_weather, previous_weather) %>% distinct()

write_rds(spain_weather, "data/spain_weather.Rds")


