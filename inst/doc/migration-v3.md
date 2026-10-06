# Migrating to HeatStressR v3

Use `heat_methods()` to discover canonical names, input requirements and
scientific references. Single-index functions return numeric vectors by
default; use `diagnostics = TRUE` for component temperatures and row diagnostics.

## Endpoints

| 2.x | v3 |
| --- | --- |
| wbt.Stull | wet_bulb_stull |
| hi | heat_index_rothfusz |
| swbgt | wbgt_simplified_indoor |
| apparentTemp | apparent_temperature |
| effectiveTemp | effective_temperature |
| discomInd | discomfort_index |
| wbgt.Bernard | wbgt_bernard |
| wbgt.Liljegren | wbgt_liljegren |
| tashurs2vap.pres | vapour_pressure |
| dewp2hurs | relative_humidity |
| calZenith | solar_zenith |
| indexShow | heat_methods |

`humidex()` and `heat_indices()` keep their names. `wet_bulb_romps()`,
`heat_index_lu()`, and `wbgt_simplified_abm()` are new.

## Scientific and validation changes

`heat_index_rothfusz()` and legacy `hi()` follow the NWS procedure, including
averaging the simple estimate with air temperature before choosing the
regression, and the corrected low-humidity square root. At 35 C and 10% RH,
the corrected value is about 31.916 C; 2.4.0 gave about 30.615 C.

`wbgt_simplified_abm()` uses 0.567*T + 0.393*e + 3.94;
`wbgt_simplified_indoor()` uses 0.567*T + 0.216*e + 3.38. Vapour pressure e
is in hPa. The inherited `swbgt()` maps to the indoor method.

Negative wind/radiation, out-of-range RH, non-positive pressure and non-finite
observations produce NA rows and summary warnings, including through legacy
wrappers. They are no longer silently clamped. Missing values remain silent.
Numeric scalars expand consistently; unequal non-scalar lengths are errors.

For methods with published applicability limits, extrapolated values are
computed where supported and flagged. Stull's rectangular domain is checked;
cold observations within it are marked unknown because the published
cold/dry exclusion is not defined by a complete numerical boundary.

## Liljegren

```r
result <- wbgt_liljegren(
  tas, dewp, wind_2m, radiation, time, lon, lat,
  pressure = pressure_hpa, dewpoint_policy = "cap", diagnostics = TRUE
)
result$values                 # previously $data
result$components$tnwb         # previously $Tnwb
result$components$tg           # previously $Tg
result$diagnostics$rows
result$diagnostics$solver
```

Use `time` with timezone-aware POSIX instants or offset-bearing ISO 8601
strings. Canonical calls require an instant, rather than a date-only/noon
assumption. Wind remains measured at 2 m and interval alignment is external. POSIXlt
inputs now preserve their original instants when converting zones; the
inherited conversion could reinterpret local fields as UTC.

Replace `noNAs`/`swap` with `dewpoint_policy = "cap"`, `"na"`, or `"error"`.
Only legacy adapters support swapping. Capping/rejection now applies exactly,
including small positive dew-point differences. Legacy `dewpoint_tolerance`
is accepted and validated but no longer changes that policy.

Advanced `control` names are `root_tolerance`, `residual_tolerance`,
`surface_albedo`, `globe_diameter`, and `min_wind_speed`. Defaults are unchanged.
Legacy `tolerance` still maps to root/residual controls in its adapter.
Canonical calls always use the batch engine with scalar fallback; legacy
`engine = "scalar"` remains available for reference comparisons.

## Bulk calculations

`heat_indices()` now selects **all** methods with supplied required inputs.
Temperature/RH alone select eight methods, including Romps and Lu. Adding
dew point selects Bernard; providing all Liljegren inputs selects Liljegren.
An all-NA supplied vector satisfies availability and yields missing rows.

Pass `wind_10m` for apparent/effective temperature and `wind_2m` for Liljegren.
Legacy `wind` is a deprecated 10 m alias. No height is substituted or adjusted.
Put Liljegren-specific controls in `liljegren_options`.

Use explicit canonical `indices` for stable schemas and costs. Deprecated
index aliases remain accepted and preserve explicitly requested column labels.
Two aliases resolving to the same method cannot be requested together.
Bulk diagnostics contain named lists by requested method.

## Dependency versions and deprecation removal

Romps and Lu delegate to the authors' `heatindex` package. Celsius, percent
RH and hPa are converted to upstream Kelvin, RH fractions and Pa at the
adapter boundary. The authors' phase convention switches at 273.16 K;
consult the catalog when applying several methods below freezing.

Fixtures and reproducibility CI pin version 0.0.2. Runtime installations
accept compatible newer versions. Pin your application environment when
reproducing published numerical results, and record diagnostic metadata.

All 2.x adapters warn once per session. They are isolated in `R/compat-v2.R`;
[the removal manifest](../DEPRECATIONS.md) identifies code, exports, registry
aliases, integration hooks and tests to remove for v4.
