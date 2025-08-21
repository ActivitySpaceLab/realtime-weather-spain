---
layout: default
title: Real-time Weather Spain Documentation
---

# Real-time Weather Spain

## Overview

This project collects weather data throughout Spain using the AEMET OpenData API. The system collects current observations, historical data, and forecasts to build a complete weather database.

## Quick Start

1. **Setup**: Configure API credentials in `auth/keys.R`
2. **Current Data**: Run `code/get_latest_data_expanded.R` for real-time observations
3. **Historical Data**: Run `code/get_historical_data.R` for historical backfill
4. **Forecasts**: Run `code/get_forecast_data.R` for 7-day predictions

## Data Sources

### AEMET OpenData API Endpoints

| Endpoint | Purpose | Frequency | Variables |
|----------|---------|-----------|-----------|
| `/api/observacion/convencional/todas` | Current observations | Hourly | 39 variables |
| `/api/valores/climatologicos/diarios/datos/` | Historical daily | Daily | 57 variables |
| `/api/prediccion/especifica/municipio/diaria/` | Municipal forecasts | Daily, 7 days ahead | 16 variables |

## Key Features

- **Multi-temporal Coverage**: Current observations, historical data (2013+), and 7-day forecasts
- **Station-level Data**: Individual weather station observations
- **Municipal Aggregations**: Municipality-level summaries and forecasts
- **Variable Compatibility**: Careful mapping between different API endpoints
- **Automated Collection**: Scheduled updates via cron jobs

## Data Structure

### Output Files

1. **`spain_weather.csv.gz`**: Hourly observations from all stations
2. **`spain_weather_daily_historical.csv.gz`**: Daily historical climatology
3. **`spain_weather_daily_aggregated.csv.gz`**: Daily station aggregations
4. **`spain_weather_municipal_forecast.csv.gz`**: Municipal 7-day forecasts

## Navigation

- [API Analysis](api-analysis.html) - Detailed endpoint analysis and variable compatibility
- [Data Structure](data-structure.html) - Database schema and file formats
- [Scripts Documentation](scripts.html) - Comprehensive script reference
- [Variable Reference](variables.html) - Complete variable definitions

## Recent Updates

**August 2025**: Major expansion from 5 to 7 core variables with comprehensive forecast integration.
