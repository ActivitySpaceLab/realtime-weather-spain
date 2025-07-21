# Data Directory

This directory contains the main weather data files generated and used by the scripts in this project.

## Contents
- `spain_weather.csv.gz` — Compressed CSV file containing the latest real-time weather observations from AEMET stations across Spain. Updated frequently by the `get_latest_data.R` script.
- `spain_weather_daily_historical.csv.gz` — Compressed CSV file containing the historical daily weather data for Spain, maintained and updated by the `get_historical_data.R` script.

## Data Table Metadata

### spain_weather.csv.gz
This table contains the most recent weather observations in long format. Typical columns include:
- `fint` — Datetime of the observation (UTC)
- `idema` — Station identifier
- `measure` — Type of measurement (`tamax`, `tamin`, or `hr`)
- `value` — Value of the measurement (numeric, may be temperature in °C or relative humidity in %)

### spain_weather_daily_historical.csv.gz
This table contains daily aggregated weather data for each station. Typical columns include:
- `date` — Date of observation (YYYY-MM-DD)
- `indicativo` — Station identifier
- `TX` — Daily maximum temperature (°C)
- `TN` — Daily minimum temperature (°C)
- `HRX` — Daily maximum relative humidity (%)
- `HRN` — Daily minimum relative humidity (%)

## Notes
- These files are automatically generated and updated by the scripts; do not edit them manually.
- Data is stored in compressed format to save space and improve performance.
- For more information on the data structure, see the script comments or open the files in a suitable data analysis tool.
