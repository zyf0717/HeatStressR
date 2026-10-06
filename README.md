# HeatStressR

[![R-CMD-check](https://github.com/zyf0717/HeatStressR/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/zyf0717/HeatStressR/actions/workflows/R-CMD-check.yaml)
[![CRAN status](https://www.r-pkg.org/badges/version/HeatStressR)](https://CRAN.R-project.org/package=HeatStressR)

HeatStressR calculates meteorological heat-stress metrics from aligned
observations. Version 3 introduces canonical snake_case endpoints, one method
registry, common validation and diagnostics, Romps thermodynamic wet bulb,
and the simplified 2026 Lu Heat Index.

HeatStressR is an independently maintained GPL-3 fork of
[HeatStress at `f77a263`](https://github.com/anacv/HeatStress/tree/f77a263ba6820a79b7092518ff4376c787ac45b2).
Ana Casanueva wrote the original package and R translation; Yifei Zheng
maintains this fork. It is not affiliated with the original project or authors.

Use `citation("HeatStressR")` for the package citation. Please also cite the
original methodological reference for each heat-stress method used; see the
corresponding function documentation.

## Install

Requires R 4.1 or later. The new Romps and Lu methods depend on the authors'
[`heatindex`](https://github.com/davidromps/heatindex) package; source installs
of that dependency require C++17/Rcpp. HeatStressR itself contains R code.

```r
install.packages("HeatStressR")
# Development version:
remotes::install_github("zyf0717/HeatStressR")
library(HeatStressR)
heat_methods()
```

Package attachment performs no networking or version checks.

## Calculate indices

Temperatures are Celsius, humidity is percent, pressure is hPa, wind is m/s,
and downwelling shortwave radiation is W/m². See `heat_methods()` for each
method's requirements, humidity phase convention, units and references.
Humidex uses a Celsius-equivalent index scale.

```r
heat_index_rothfusz(c(25, 35), c(50, 10))
heat_index_lu(c(25, 35), c(50, 70))
wet_bulb_romps(30, 70, pressure = 950)
wbgt_simplified_abm(30, 70)
wbgt_simplified_indoor(30, 70)

indices <- heat_indices(c(25, 30), c(60, 70))
selected <- heat_indices(
  c(25, 30), c(60, 70), wind_10m = c(1, 2),
  indices = c("humidex", "heat_index_lu", "apparent_temperature")
)
```

`heat_indices()` automatically selects every method supported by supplied
inputs, including numerical methods. Select indices explicitly for stable
columns and predictable computation. It does not infer missing humidity
inputs or substitute wind heights.

`wet_bulb_romps()` calculates thermodynamic liquid-water wet bulb. Natural
wet bulb, aspirated wet bulb and WBGT are different quantities. The ABM and
indoor simplified WBGT formulas also represent different approximations.

## Liljegren WBGT

The existing vectorized R heat-balance solver remains the implementation,
with automatic scalar fallback and optional PSOCK workers. Wind must be at
2 m; adjust other heights externally. Supply timestamps as instants and
align interval data before calculation.

```r
time <- as.POSIXct(
  c("2024-06-01 12:00:00", "2024-06-01 13:00:00"), tz = "UTC"
)
wbgt <- wbgt_liljegren(
  tas = c(30, 31), dewp = c(22, 22.5), wind = c(1.5, 2),
  radiation = c(700, 750), time = time, lon = 0, lat = 15,
  direct_fraction = c(0.6, 0.8)
)
detail <- wbgt_liljegren(
  30, 22, 1.5, 700, time[1], 0, 15, diagnostics = TRUE
)
detail$components
```

Pressure defaults to 1010 hPa, an explicit near-sea-level assumption.
`control` groups advanced root/residual precision, albedo, globe diameter
and minimum wind speed. Use `workers > 1` only for a sufficiently large call
and avoid nesting worker pools.

The model is an independently maintained R implementation, rather than a
bitwise port of the original C program. Match physical assumptions when
comparing implementations.

## Validation and diagnostics

Numeric scalars expand to the common observation length. Other incompatible
lengths and wrong types raise errors. Missing observations propagate silently.
Physically invalid rows return NA with one summary warning. Observations
outside a documented applicability domain are calculated where possible,
flagged, and summarized in a warning. An unknown validity boundary is recorded
as unknown. Numerical failures are distinct from invalid input.

Single-index functions return numeric vectors. With `diagnostics = TRUE`,
they return `list(values, components, diagnostics)`. The diagnostics contain
aligned row statuses, optional solver details and scientific metadata. Bulk
calculations return a data frame or the corresponding diagnostic list.

Below freezing, published methods differ in their humidity reference phase.
Use the convention reported by `heat_methods()` and do not assume that
water-relative and ice-relative RH are interchangeable.

## Migration and reproducibility

Legacy 2.x names remain as deprecated adapters and warn once per session.
Removal is planned no earlier than v4.0.0. `hi()` uses the corrected NWS
procedure; `swbgt()` continues to represent the indoor approximation.

- [v3 migration guide](inst/doc/migration-v3.md)
- [Compatibility removal manifest](inst/DEPRECATIONS.md)
- [Liljegren inputs](inst/doc/liljegren-inputs.md)
- [Parallel execution](inst/doc/parallelism.md)
- [Other indices](inst/doc/non-liljegren-indices.md)
- [Benchmarking](inst/doc/benchmarking.md)

Reference fixtures use `heatindex` 0.0.2. The runtime dependency accepts
compatible later versions; pin the dependency in your own environment for
identical reproducibility. Diagnostic metadata reports the installed version.
Use `tools/install-reference-dependencies.R` for the pinned validation library.

For local source tests, use an isolated library containing this checkout so
PSOCK workers load the same package version as the parent:

```sh
Rscript tools/install-reference-dependencies.R /tmp/heatstressr-test-library
R_LIBS=/tmp/heatstressr-test-library R CMD INSTALL --library=/tmp/heatstressr-test-library .
R_LIBS=/tmp/heatstressr-test-library Rscript -e 'testthat::test_local()'
```
