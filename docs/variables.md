---
layout: default
title: Variable Reference
---

# Variable Reference

## Core Variables (Cross-Endpoint Compatible)

### Temperature Variables
- **`ta`** - Air temperature (°C)
  - Current: Instantaneous reading
  - Historical: Daily mean
  - Forecast: Average daily temperature

- **`tamax`** - Maximum temperature (°C)
  - Current: Maximum in past hour/period
  - Historical: Daily maximum
  - Forecast: Daily maximum

- **`tamin`** - Minimum temperature (°C)
  - Current: Minimum in past hour/period
  - Historical: Daily minimum
  - Forecast: Daily minimum

### Atmospheric Variables
- **`hr`** - Relative humidity (%)
  - Current: Instantaneous reading
  - Historical: Daily mean/max/min available
  - Forecast: Daily average

- **`p`** - Atmospheric pressure (hPa)
  - Current: Station-level pressure
  - Historical: Daily mean
  - Forecast: Not available

- **`prec`** - Precipitation (mm)
  - Current: Accumulated since last reading
  - Historical: Daily total
  - Forecast: Daily total

### Wind Variables
- **`vv`** - Wind speed (km/h)
  - Current: Mean wind speed
  - Historical: Daily mean
  - Forecast: Daily average

## Current Observations Extended Variables

### Additional Atmospheric
- **`dp`** - Dew point (°C)
- **`vis`** - Visibility (km)
- **`pres`** - Sea-level pressure (hPa)

### Wind Details
- **`rachamax`** - Maximum wind gust (km/h)
- **`dd`** - Wind direction (degrees)
- **`ddd`** - Dominant wind direction

### Solar and Radiation
- **`rs`** - Solar radiation
- **`tuv`** - UV index

## Historical Daily Extended Variables

### Humidity Details
- **`hrx`** - Maximum relative humidity (%)
- **`hrn`** - Minimum relative humidity (%)
- **`hrd`** - Dominant humidity

### Temperature Analysis
- **`tx`** - Extreme maximum temperature (°C)
- **`tam`** - Monthly average temperature (°C)

### Wind Analysis  
- **`racha`** - Maximum wind gust (km/h) [cf. rachamax]
- **`dir`** - Predominant wind direction

## Forecast Variables

### Daily Forecasts
- **`temperatura.maxima`** - Daily maximum temperature (°C)
- **`temperatura.minima`** - Daily minimum temperature (°C)
- **`temperatura.dato`** - Representative temperature (°C)

- **`humedadRelativa.maxima`** - Maximum relative humidity (%)
- **`humedadRelativa.minima`** - Minimum relative humidity (%)
- **`humedadRelativa.dato`** - Representative humidity (%)

- **`probPrecipitacion`** - Precipitation probability (%)
- **`viento`** - Wind information (direction/speed)
- **`rachaMax`** - Maximum wind gust forecast (km/h)

### Weather Conditions
- **`estadoCielo`** - Sky condition code
- **`uvMax`** - Maximum UV index
- **`cotaNieveProv`** - Snow level (m)

## Variable Mapping Strategy

### Aggregation Rules for Daily Summaries

| Variable | Current→Daily | Rule |
|----------|---------------|------|
| `ta` | Mean of hourly values | `mean(ta, na.rm=TRUE)` |
| `tamax` | Maximum of hourly values | `max(tamax, na.rm=TRUE)` |
| `tamin` | Minimum of hourly values | `min(tamin, na.rm=TRUE)` |
| `hr` | Mean of hourly values | `mean(hr, na.rm=TRUE)` |
| `prec` | Sum of hourly values | `sum(prec, na.rm=TRUE)` |
| `vv` | Mean of hourly values | `mean(vv, na.rm=TRUE)` |
| `p` | Mean of hourly values | `mean(p, na.rm=TRUE)` |

### Cross-Endpoint Harmonization

When combining data from different endpoints:

1. **Temperature**: Direct mapping (ta ↔ ta)
2. **Wind gusts**: Map rachamax (current) ↔ racha (historical)
3. **Humidity**: Use base hr variable for consistency
4. **Precipitation**: Sum hourly to get daily totals

## Data Quality Indicators

### Missing Value Codes
- **Current**: `NA` for missing sensors
- **Historical**: Specific codes for different missing types
- **Forecast**: Complete coverage (no missing values)

### Typical Ranges (Spain)
- **Temperature**: -20°C to 50°C
- **Humidity**: 0% to 100%
- **Precipitation**: 0mm to 200mm/day (extreme events higher)
- **Wind speed**: 0 to 150+ km/h
- **Pressure**: 950 to 1050 hPa

---

*Variable definitions based on AEMET documentation and API response analysis.*
