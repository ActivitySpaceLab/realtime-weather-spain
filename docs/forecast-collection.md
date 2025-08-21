# Forecast Data Collection

## Overview

The forecast data collection system has been expanded to cover ALL Spanish municipalities (8,129 total) using the AEMET OpenData API. The system now loads municipality codes from the comprehensive dataset in `data/municipalities.csv.gz`.

## Scripts Available

### 1. get_forecast_data.R (Original Enhanced)
- **Purpose**: Collects 7-day daily forecasts for all Spanish municipalities
- **Data Source**: Loads all 8,129 municipality CUMUN codes from `data/municipalities.csv.gz`
- **Configuration**: 
  - `SAMPLE_SIZE = 50` for testing (set to `NULL` for full collection)
  - `PREVENT_CONCURRENT_RUNS = FALSE` by default
- **Output**: Daily forecasts with variables compatible with observation data

### 2. get_forecast_data_simple.R (Robust Alternative)
- **Purpose**: More robust forecast collection with better error handling
- **Features**: Enhanced progress tracking, better timeout handling, cleaner error recovery
- **Configuration**: Same as original but with improved stability
- **Recommended**: Use this version for large-scale collection

## Municipality Coverage

The system now processes:
- **Total Municipalities**: 8,129 (complete coverage of Spain)
- **Data Source**: `data/municipalities.csv.gz` with CUMUN codes and NAMEUNIT names
- **Testing Mode**: Set `SAMPLE_SIZE = 20` for quick validation
- **Production Mode**: Set `SAMPLE_SIZE = NULL` for complete collection

## API Considerations

Current challenges with forecast collection:
1. **Rate Limiting**: AEMET API has strict rate limits causing "Server returned nothing" errors
2. **Connection Timeouts**: Large-scale collection requires careful pacing
3. **Success Rate**: Currently experiencing connectivity issues during testing

## Recommended Approach

For successful large-scale forecast collection:

1. **Start Small**: Test with `SAMPLE_SIZE = 10-20` municipalities
2. **Increase Delays**: Consider longer delays between API calls
3. **Batch Processing**: Process municipalities in smaller batches
4. **Monitor Progress**: Use the built-in progress tracking

## Variable Compatibility

Forecast data uses the same 7 safe variables as observation data:
- `ta` (temperature)
- `tamax` (max temperature) 
- `tamin` (min temperature)
- `hr` (humidity)
- `prec` (precipitation)
- `vv` (wind speed)
- `pres` (pressure)

This ensures seamless integration with existing observation datasets.
