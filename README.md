# Realtime Weather - Spain

This repository provides scripts to download, update, and manage real-time and historical weather data from AEMET weather stations across Spain. The code automates the retrieval of both the latest observations and daily historical data, storing them in compressed CSV files for further analysis or integration.

## Features
- Fetches real-time weather observations from all AEMET stations.
- Updates and maintains a historical daily weather dataset.
- Handles API rate limits and errors with retry logic.
- Data is stored in compressed CSV format for efficiency.

## Requirements
- R (recommended version 4.0 or higher)
- API key for AEMET OpenData (see below)
- R packages: tidyverse, lubridate, data.table, curl, jsonlite, RSocrata, R.utils

## Setup
1. **API Key**: Obtain an API key from [AEMET OpenData](https://opendata.aemet.es/centrodedescargas/inicio).
2. **Auth Directory**: Place your API key as `my_api_key` in a file called `keys.R` inside an untracked `auth/` directory:
   ```r
   my_api_key <- "YOUR_API_KEY_HERE"
   ```
3. **Install Dependencies**: Install required R packages if not already present.

## Usage
- Run `code/get_latest_data.R` to fetch and append the latest weather observations (recommended every 2 hours).
- Run `code/get_historical_data.R` to update the historical daily weather dataset (run as needed).
- Output files are written to the `data/` directory as compressed CSVs.

## Directory Structure
```
realtime-weather-spain/
├── auth/                  # Untracked directory for API keys
│   └── keys.R
├── code/                  # Main R scripts
│   ├── get_historical_data.R
│   └── get_latest_data.R
├── data/                  # Output data files
│   ├── spain_weather.csv.gz
│   └── spain_weather_daily_historical.csv.gz
├── logs/                  # Log files and script outputs
├── renv/                  # R environment and package management
├── update_weather.sh      # Shell script for automation
├── update_historical_weather.sh
├── README.md
└── ...
```

## Notes
- The `auth/` directory is not tracked by git for security.
- Scripts are designed to be robust to API failures and rate limits.
- For more details, see comments in each script.

## License
See `LICENSE` file for details.
