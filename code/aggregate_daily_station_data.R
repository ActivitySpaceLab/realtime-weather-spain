#!/usr/bin/env Rscript

# aggregate_daily_station_data.R
# -------------------------------
# Purpose: Create daily aggregated weather data by station from hourly observations
#
# This script processes the hourly expanded weather data to create daily summaries
# by station. It combines historical daily data with aggregated current observations
# to provide a complete time series from 2013 to present.
#
# Output: Daily means, minimums, maximums, and totals by weather station
#
# Data Sources:
#   1. Historical daily data (2013 to T-4 days) from AEMET climatological endpoint
#   2. Current hourly data (T-4 days to present) aggregated to daily values
#
# Author: John Palmer
# Date: 2025-08-20

rm(list=ls())

# Dependencies ####
library(tidyverse)
library(lubridate)
library(data.table)

cat("=== DAILY STATION DATA AGGREGATION ===\n")

# Check if expanded hourly data exists
if(!file.exists("data/spain_weather_expanded.csv.gz")) {
  cat("ERROR: Expanded hourly weather data not found. Run get_latest_data_expanded.R first.\n")
  quit(save="no", status=1)
}

# Load expanded hourly data
cat("Loading hourly expanded weather data...\n")
hourly_data = fread("data/spain_weather_expanded.csv.gz")
hourly_data$fint = as_datetime(hourly_data$fint)
hourly_data$date = as.Date(hourly_data$fint)

cat("Loaded", nrow(hourly_data), "hourly observation records.\n")
cat("Date range:", min(hourly_data$date, na.rm=TRUE), "to", max(hourly_data$date, na.rm=TRUE), "\n")

# Load historical daily data if it exists
historical_daily = NULL
if(file.exists("data/spain_weather_daily_historical.csv.gz")) {
  cat("Loading historical daily data...\n")
  historical_daily = fread("data/spain_weather_daily_historical.csv.gz")
  
  # Standardize historical data format
  if("fecha" %in% names(historical_daily)) {
    historical_daily$date = as.Date(historical_daily$fecha)
  }
  
  # Select compatible variables and reshape to match hourly format
  historical_compatible = historical_daily %>%
    filter(!is.na(date)) %>%
    select(any_of(c("date", "idema", "ta", "tamax", "tamin", "hr", "prec", "vv", "p"))) %>%
    pivot_longer(cols = c(-date, -idema), names_to = "measure", values_to = "value") %>%
    filter(!is.na(value)) %>%
    mutate(source = "historical_daily") %>%
    as.data.table()
  
  cat("Loaded", nrow(historical_compatible), "historical daily records.\n")
  cat("Historical date range:", min(historical_compatible$date, na.rm=TRUE), "to", max(historical_compatible$date, na.rm=TRUE), "\n")
} else {
  cat("No historical daily data found. Using only current observations.\n")
  historical_compatible = data.table()
}

# Aggregate hourly data to daily values
cat("Aggregating hourly data to daily summaries...\n")

# Define aggregation rules for each variable
aggregate_hourly_to_daily = function(hourly_dt) {
  daily_aggregated = hourly_dt %>%
    group_by(date, idema, measure) %>%
    summarise(
      value = case_when(
        measure %in% c("ta", "hr", "vv", "pres") ~ mean(value, na.rm = TRUE),   # Mean for these variables
        measure %in% c("tamax") ~ max(value, na.rm = TRUE),                     # Maximum for tamax
        measure %in% c("tamin") ~ min(value, na.rm = TRUE),                     # Minimum for tamin  
        measure %in% c("prec") ~ sum(value, na.rm = TRUE),                      # Sum for precipitation
        TRUE ~ mean(value, na.rm = TRUE)                                        # Default to mean
      ),
      n_observations = n(),
      source = "hourly_aggregated",
      .groups = "drop"
    ) %>%
    filter(!is.na(value) & !is.infinite(value)) %>%
    as.data.table()
  
  return(daily_aggregated)
}

daily_from_hourly = aggregate_hourly_to_daily(hourly_data)
cat("Created", nrow(daily_from_hourly), "daily aggregated records from hourly data.\n")

# Combine historical and aggregated current data
if(nrow(historical_compatible) > 0) {
  # Find overlap period to avoid duplication
  hourly_start_date = min(daily_from_hourly$date, na.rm = TRUE)
  historical_end_date = max(historical_compatible$date, na.rm = TRUE)
  
  cat("Hourly data starts:", hourly_start_date, "\n")
  cat("Historical data ends:", historical_end_date, "\n")
  
  # Use historical data up to the start of hourly data, then use aggregated hourly
  if(hourly_start_date <= historical_end_date) {
    # Overlap exists - use historical up to day before hourly starts
    cutoff_date = hourly_start_date - days(1)
    historical_to_use = historical_compatible[date <= cutoff_date]
    cat("Using historical data through", cutoff_date, "\n")
  } else {
    # No overlap - use all historical
    historical_to_use = historical_compatible
    cat("No overlap - using all historical data.\n")
  }
  
  # Add n_observations column to historical data
  historical_to_use$n_observations = 1
  
  # Combine datasets
  combined_daily = rbind(historical_to_use, daily_from_hourly, fill = TRUE)
} else {
  combined_daily = daily_from_hourly
}

# Sort and clean the combined dataset
combined_daily = combined_daily[order(date, idema, measure)]

# Create summary statistics
cat("\n=== DAILY AGGREGATION SUMMARY ===\n")
cat("Total daily records:", nrow(combined_daily), "\n")
cat("Date range:", min(combined_daily$date, na.rm=TRUE), "to", max(combined_daily$date, na.rm=TRUE), "\n")
cat("Number of stations:", length(unique(combined_daily$idema)), "\n")
cat("Variables included:", paste(unique(combined_daily$measure), collapse=", "), "\n")

# Summary by source
source_summary = combined_daily[, .(
  records = .N,
  stations = length(unique(idema)),
  date_min = min(date, na.rm=TRUE),
  date_max = max(date, na.rm=TRUE)
), by = source]

print(source_summary)

# Check data coverage by variable
cat("\n=== VARIABLE COVERAGE ===\n")
variable_coverage = combined_daily[, .(
  records = .N,
  stations = length(unique(idema)),
  date_min = min(date, na.rm=TRUE),
  date_max = max(date, na.rm=TRUE),
  mean_obs_per_station_day = mean(n_observations, na.rm=TRUE)
), by = measure]

print(variable_coverage)

# Save the aggregated daily data
output_file = "data/spain_weather_daily_aggregated.csv.gz"
fwrite(combined_daily, output_file)

cat("\n=== AGGREGATION COMPLETE ===\n")
cat("Daily aggregated data saved to:", output_file, "\n")
cat("File size:", round(file.size(output_file)/1024/1024, 1), "MB\n")
