# AEMET Variable Documentation
# Complete list of variables from AEMET OpenData API (39 total variables)

## High Coverage Variables (>95% non-NA):
- **idema** — Station identifier (100% coverage)
- **lon** — Longitude (100% coverage)
- **fint** — Date and time of observation UTC (100% coverage)
- **alt** — Altitude/elevation of station (100% coverage)
- **lat** — Latitude (100% coverage)
- **ubi** — Station location/name (100% coverage)
- **hr** — Relative humidity (98.7% coverage)
- **tamin** — Minimum temperature (98.4% coverage)
- **ta** — Current air temperature (98.4% coverage)
- **tamax** — Maximum temperature (98.4% coverage)

## Moderate Coverage Variables (likely station-dependent):
- **prec** — Precipitation (mm)
- **vmax** — Maximum wind speed
- **vv** — Wind speed (average)
- **dv** — Wind direction (degrees)
- **dmax** — Direction of maximum wind (degrees)
- **pres** — Atmospheric pressure (hPa)
- **pres_nmar** — Sea level pressure (hPa)
- **ts** — Surface temperature
- **tpr** — Dew point temperature
- **vis** — Visibility (km)
- **inso** — Sunshine duration (hours)
- **stdvv** — Standard deviation of wind speed
- **stddv** — Standard deviation of wind direction

## Low Coverage/Specialized Variables:
- **tss5cm** — Soil temperature at 5cm depth
- **tss20cm** — Soil temperature at 20cm depth
- **nieve** — Snow depth/coverage
- **psoltp** — Solid precipitation type
- **pliqt** — Liquid precipitation type
- **rviento** — Wind-related variable
- **vmaxu** — Maximum wind speed (upper level?)
- **dvu** — Wind direction (upper level?)
- **pacutp** — Accumulated precipitation type
- **vvu** — Wind speed (upper level?)
- **stdvvu** — Standard deviation wind speed (upper level)
- **stddvu** — Standard deviation wind direction (upper level)
- **dmaxu** — Direction of maximum wind (upper level)
- **geo850** — Geopotential height at 850 hPa
- **geo925** — Geopotential height at 925 hPa
- **geo700** — Geopotential height at 700 hPa

## Recommended Variables for Expanded Dataset:
For good data coverage across stations, focus on these variables:
- **Core variables**: idema, lon, lat, fint, alt, ubi
- **Temperature**: ta, tamin, tamax, ts, tpr
- **Humidity**: hr
- **Wind**: vv, dv, vmax, dmax, stdvv, stddv
- **Pressure**: pres, pres_nmar
- **Precipitation**: prec
- **Visibility/Solar**: vis, inso

## Notes:
- Variables with 'u' suffix likely refer to upper-level measurements
- Geopotential heights (geo700, geo925, geo850) are atmospheric layers
- Many specialized variables have very low coverage and may be station-specific
- Temperature values are in Celsius
- Wind speeds typically in m/s
- Pressure in hPa (hectopascals)
- Precipitation in mm

## Data Quality:
- 39 total variables available
- Core meteorological variables have >95% coverage
- Specialized/upper-level variables often have 0% coverage
- Station equipment determines variable availability
