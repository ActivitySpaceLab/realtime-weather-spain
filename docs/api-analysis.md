---
layout: default
title: AEMET API Analysis
---

# AEMET API Analysis

## Executive Summary

Analysis of AEMET OpenData API endpoints reveals three distinct data streams with different variable schemas and temporal coverage. **Key finding**: 18 variables are common between current and historical endpoints, enabling safe expansion from 5 to 7 core meteorological variables.

## Variable Compatibility Results

### Endpoint Overview

| Endpoint | Variables Available | Temporal Coverage | Update Frequency |
|----------|-------------------|------------------|------------------|
| Current Observations | 39 variables | Real-time hourly | Every hour |
| Historical Daily | 57 variables | Daily summaries back to 2013 | Daily (4-day lag) |
| Forecast Hourly | 5 variables | 3 days ahead | Twice daily |
| Forecast Daily | 16 variables | 7 days ahead | Twice daily |

### Safe Variables for Expansion

These 7 variables exist across both current and historical endpoints and are recommended for expansion:

1. `hr` - Relative humidity (%)
2. `pres` - Atmospheric pressure (hPa) 
3. `prec` - Precipitation (mm)
4. `ta` - Air temperature (°C)
5. `tamax` - Maximum temperature (°C)
6. `tamin` - Minimum temperature (°C)
7. `vv` - Wind speed (km/h)

### Important Note on Pressure Variables

AEMET provides two pressure variables:
- `p` - Available only in historical data (appears to be mostly empty in current observations)
- `pres` - Available in both current and historical data (contains actual pressure measurements)

**Recommendation**: Use `pres` for pressure measurements as it contains actual data across both endpoints.

**Date of Analysis**: August 20, 2025

## Endpoint Comparison

### Current Observations
- **Endpoint**: `/api/observacion/convencional/todas`
- **Variables**: 39 available
- **Frequency**: Hourly updates
- **Coverage**: All active weather stations
- **Data Quality**: Real-time, some missing values

### Historical Daily
- **Endpoint**: `/api/valores/climatologicos/diarios/datos/`
- **Variables**: 57 available (different schema)
- **Frequency**: Daily summaries
- **Coverage**: 2013 to 4 days ago
- **Data Quality**: Quality-controlled, complete records

### Municipal Forecasts
- **Endpoint**: `/api/prediccion/especifica/municipio/diaria/`
- **Variables**: 16 forecast variables
- **Frequency**: Daily updates
- **Coverage**: 7 days ahead
- **Spatial Unit**: Municipalities (not stations)

## Variable Compatibility Matrix

### Core Variables (Safe for All Endpoints)

| Variable | Current | Historical | Forecast | Description |
|----------|---------|------------|----------|-------------|
| `ta` | ✅ | ✅ | ✅ | Air temperature |
| `tamax` | ✅ | ✅ | ✅ | Maximum temperature |
| `tamin` | ✅ | ✅ | ✅ | Minimum temperature |
| `hr` | ✅ | ✅ | ✅ | Relative humidity |
| `prec` | ✅ | ✅ | ✅ | Precipitation |
| `vv` | ✅ | ✅ | ✅ | Wind speed |
| `p` | ✅ | ✅ | ❌ | Atmospheric pressure |

### Current-Only Variables (Real-time Enhancement)

| Variable | Description | Use Case |
|----------|-------------|----------|
| `rachamax` | Wind gust maximum | Extreme weather monitoring |
| `vis` | Visibility | Aviation, transport |
| `dp` | Dew point | Comfort indices |

### Forecast-Specific Variables

| Variable | Description | Forecast Type |
|----------|-------------|---------------|
| `temperatura.maxima` | Daily maximum temperature | Daily |
| `temperatura.minima` | Daily minimum temperature | Daily |
| `humedadRelativa.dato` | Average relative humidity | Daily |
| `probPrecipitacion` | Precipitation probability | Daily |

## Implementation Recommendations

### Phase 1: Core Variable Expansion
Expand from current 5 variables to 7 core variables available across all endpoints:
- Temperature: `ta`, `tamax`, `tamin`
- Humidity: `hr`
- Precipitation: `prec`
- Wind: `vv`
- Pressure: `p` (current/historical only)

### Phase 2: Forecast Integration
Add municipal 7-day forecasts as separate data stream with compatible variable mapping.

### Phase 3: Enhanced Monitoring
Consider adding current-only variables for specialized applications.

## Data Continuity Strategy

```
Historical Daily (2013 → T-4 days)
    ↓
Current Hourly (T-4 days → present) → Daily aggregation
    ↓  
Municipal Forecasts (present → T+7 days)
```

## Technical Considerations

### Encoding Issues
- **Problem**: Forecast endpoints return latin1 encoded data
- **Solution**: Set `Encoding(response) = "latin1"` before JSON parsing

### Rate Limiting
- **Limit**: Unknown, but conservative approach recommended
- **Strategy**: Implement delays between requests and lock files

### Variable Naming Differences
- Wind gusts: `rachamax` (current) vs `racha` (historical)
- Requires mapping logic in aggregation scripts

## Quality Assessment

### Data Completeness by Endpoint

| Endpoint | Completeness | Notes |
|----------|--------------|-------|
| Current | ~85% | Some stations offline, weather-dependent gaps |
| Historical | ~95% | Quality-controlled, consistent |
| Forecast | 100% | Complete municipal coverage |

### Recommended Quality Filters
- Exclude stations with >50% missing data in recent month
- Flag extreme values outside climatological bounds
- Cross-validate current vs historical overlaps

---

*Analysis conducted using inspect_variables.R, test_historical_variables.R, and analyze_forecast_data.R scripts.*
