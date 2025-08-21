#!/usr/bin/env Rscript

# Variable compatibility analysis across AEMET endpoints
# Compares current observations (39 vars), historical daily (25 vars), and forecast variables

# Load necessary libraries
suppressPackageStartupMessages({
  library(curl)
  library(jsonlite)
  library(dplyr)
})

# Load API key
source("auth/keys.R")

cat("=== AEMET API VARIABLE COMPATIBILITY ANALYSIS ===\n\n")

# Variables from current observations (from inspect_variables.R output)
current_vars = c(
  "alt", "bh", "ca", "cel", "dd", "ddd", "dp", "dv", "dvi", "dvm", "fxi", "fxv", 
  "hr", "lat", "lon", "pmax", "pmin", "prec", "pres", "qp", "r", "rachamax", 
  "ri", "rs", "sol", "ta", "tamax", "tamin", "ts", "tuv", "v", "vis", "vmax", 
  "vv", "w", "ww", "xi", "za"
)

# Variables from historical daily data (from test_historical_variables.R output)
historical_vars = c(
  "alt", "bh", "ca", "cel", "dir", "dv", "hr", "hrd", "hrh", "hrhf", "hrhh", 
  "hri", "hrn", "hrnf", "hrnh", "hrx", "hrxf", "hrxh", "lat", "lon", 
  "pmd", "prec", "pres", "psd", "q", "qa", "qmax", "qmin", "racha", "sol", 
  "solh", "solhd", "solhf", "tad", "tadf", "tadh", "tam", "tamax", 
  "tamaxf", "tamaxh", "tamin", "taminf", "taminh", "tx", "txd", "txf", "txh", 
  "vv", "vvd", "vvh", "vvhd", "vvhf", "vvhh", "w", "ww"
)

# Forecast variables from analysis
# Compares current observations (39 vars), historical daily (25 vars), and forecast variables

# Load necessary libraries
suppressPackageStartupMessages({
  library(curl)
  library(jsonlite)
  library(dplyr)
})

# Load API key
source("auth/keys.R")

cat("=== AEMET API VARIABLE COMPATIBILITY ANALYSIS ===\n\n")

# Variables from current observations (from inspect_variables.R output)
current_vars = c(
  "alt", "bh", "ca", "cel", "dd", "ddd", "dp", "dv", "dvi", "dvm", "fxi", "fxv", 
  "hr", "lat", "lon", "pmax", "pmin", "prec", "pres", "qp", "r", "rachamax", 
  "ri", "rs", "sol", "ta", "tamax", "tamin", "ts", "tuv", "v", "vis", "vmax", 
  "vv", "w", "ww", "xi", "za"
)

# Variables from historical daily data (from test_historical_variables.R output)
historical_vars = c(
  "alt", "bh", "ca", "cel", "dir", "dv", "hr", "hrd", "hrh", "hrhf", "hrhh", 
  "hri", "hrn", "hrnf", "hrnh", "hrx", "hrxf", "hrxh", "lat", "lon", "p", 
  "pmd", "prec", "pres", "psd", "q", "qa", "qmax", "qmin", "racha", "sol", 
  "solh", "solhd", "solhf", "ta", "tad", "tadf", "tadh", "tam", "tamax", 
  "tamaxf", "tamaxh", "tamin", "taminf", "taminh", "tx", "txd", "txf", "txh", 
  "vv", "vvd", "vvh", "vvhd", "vvhf", "vvhh", "w", "ww"
)

# Variables from forecast analysis
forecast_hourly_vars = c(
  "estadoCielo", "precipitacion", "temperatura", "vientoAndRachaMax", "humedadRelativa"
)

forecast_daily_vars = c(
  "probPrecipitacion", "cotaNieveProv", "estadoCielo", "viento", "rachaMax", 
  "uvMax", "fecha", "temperatura.maxima", "temperatura.minima", "temperatura.dato", 
  "sensTermica.maxima", "sensTermica.minima", "sensTermica.dato", 
  "humedadRelativa.maxima", "humedadRelativa.minima", "humedadRelativa.dato"
)

cat("VARIABLE COUNTS BY ENDPOINT:\n")
cat("-----------------------------\n")
cat("Current observations:", length(current_vars), "variables\n")
cat("Historical daily:", length(historical_vars), "variables\n") 
cat("Forecast hourly:", length(forecast_hourly_vars), "variables\n")
cat("Forecast daily:", length(forecast_daily_vars), "variables\n\n")

# Find common variables between current and historical
current_historical_common = intersect(current_vars, historical_vars)
cat("VARIABLES COMMON TO CURRENT AND HISTORICAL:\n")
cat("----------------------------------------------\n")
cat("Count:", length(current_historical_common), "variables\n")
cat("Variables:", paste(sort(current_historical_common), collapse = ", "), "\n\n")

# Variables only in current observations
current_only = setdiff(current_vars, historical_vars)
cat("VARIABLES ONLY IN CURRENT OBSERVATIONS:\n")
cat("---------------------------------------\n")
cat("Count:", length(current_only), "variables\n")
cat("Variables:", paste(sort(current_only), collapse = ", "), "\n\n")

# Variables only in historical
historical_only = setdiff(historical_vars, current_vars)
cat("VARIABLES ONLY IN HISTORICAL DAILY:\n")
cat("------------------------------------\n")
cat("Count:", length(historical_only), "variables\n")
cat("Variables:", paste(sort(historical_only), collapse = ", "), "\n\n")

# Map forecast variables to current/historical equivalents
cat("FORECAST TO CURRENT/HISTORICAL MAPPING:\n")
cat("---------------------------------------\n")
cat("Forecast variable -> Current equivalent -> Historical equivalent\n\n")

forecast_mapping = data.frame(
  forecast_var = c("temperatura", "precipitacion", "humedadRelativa", "vientoAndRachaMax"),
  current_equiv = c("ta/tamax/tamin", "prec", "hr", "rachamax/dd/vv"),
  historical_equiv = c("ta/tamax/tamin/tx", "prec", "hr/hrx/hrn", "racha/dir/vv"),
  available_both = c("YES", "YES", "YES", "PARTIAL"),
  stringsAsFactors = FALSE
)

for(i in 1:nrow(forecast_mapping)) {
  cat(sprintf("%-20s -> %-15s -> %-15s [%s]\n", 
              forecast_mapping$forecast_var[i],
              forecast_mapping$current_equiv[i], 
              forecast_mapping$historical_equiv[i],
              forecast_mapping$available_both[i]))
}

cat("\n\nRECOMMENDATIONS FOR EXPANDED DATA COLLECTION:\n")
cat("=============================================\n")
cat("1. SAFE VARIABLES (available in all endpoints):\n")
safe_vars = intersect(current_historical_common, c("ta", "tamax", "tamin", "prec", "hr", "pres", "vv"))
cat("   ", paste(safe_vars, collapse = ", "), "\n\n")

cat("2. CURRENT-ONLY VARIABLES (good for real-time expansion):\n")
realtime_good = intersect(current_only, c("rachamax", "vis", "dp"))
cat("   ", paste(realtime_good, collapse = ", "), "\n\n")

cat("3. FORECAST CAPABILITIES:\n")
cat("   - Hourly forecasts: 3 days ahead\n")
cat("   - Daily forecasts: 7 days ahead\n")
cat("   - Available variables: temperature, precipitation, humidity, wind\n\n")

cat("4. IMPLEMENTATION STRATEGY:\n")
cat("   - Use common variables for consistent historical backfill\n")
cat("   - Add current-only variables for enhanced real-time monitoring\n")
cat("   - Integrate forecasts as separate data streams\n")
cat("   - Consider wind variables (rachamax vs racha) naming differences\n\n")

cat("=== ANALYSIS COMPLETE ===\n")
