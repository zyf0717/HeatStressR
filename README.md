# HeatStressR

[![R-CMD-check](https://github.com/zyf0717/HeatStressR/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/zyf0717/HeatStressR/actions/workflows/R-CMD-check.yaml)
[![CRAN status](https://www.r-pkg.org/badges/version/HeatStressR)](https://CRAN.R-project.org/package=HeatStressR)
[![Release](https://img.shields.io/github/v/release/zyf0717/HeatStressR?display_name=tag&sort=semver)](https://github.com/zyf0717/HeatStressR/releases)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](https://github.com/zyf0717/HeatStressR/blob/master/LICENSE)

> **Fork notice:** HeatStressR is an independently maintained fork of
> [HeatStress at `f77a263`](https://github.com/anacv/HeatStress/tree/f77a263ba6820a79b7092518ff4376c787ac45b2).
> It is not maintained by, or affiliated with, the original project or its
> authors.

## What is HeatStressR?

HeatStressR calculates heat-stress indices from aligned meteorological
observations. It retains the original package's public index functions while
substantially extending the Liljegren wet-bulb globe temperature (WBGT) model
and optimizing the remaining indices.

This fork was created for a workload requiring approximately **two billion
Liljegren calculations**. That scale made the inherited per-row R execution
path impractical, so the work concentrated first on vectorized numerical
solving, predictable failure handling, and scalable batch execution.

HeatStressR is an R implementation of the Liljegren model, not a
bitwise-compatible port of the original C program. Match physical assumptions
and numerical controls before comparing implementations.

## What changed since `f77a263`?

| Area | Upgrades in HeatStressR |
| --- | --- |
| Liljegren throughput | Vectorized batch solving is the default; optional local PSOCK workers split a single large calculation across processes. |
| Numerical behavior | Adaptive bracketing, residual validation, scalar fallback, and row-aligned diagnostics distinguish invalid inputs from solver failures. |
| Meteorological inputs | Timestamp-aware solar geometry, scalar or row-aligned pressure/coordinates/direct-radiation fraction, and explicit physical controls. |
| Operational use | Documented batch, parallel, timestamp, and input contracts; reproducible performance runners for large workloads. |
| Other indices | Vectorized Bernard psychrometric solves, selective NWS heat-index regression in °C, shared vapour-pressure kernels, and fused multi-index calculation through `heat_indices()`. |
| Compatibility | Existing exported function signatures and positional calling conventions are retained; `hi()` now returns °C to match its °C input. |

The largest and most mature changes are in `wbgt.Liljegren()`. The closed-form
and Bernard updates improve common non-Liljegren workflows without adding
compiled-code dependencies or changing their existing input signatures.

## Install and load

HeatStressR requires R 3.4 or later. The test suite is supported from R 4.1.

```r
install.packages("HeatStressR")
```

### Development version

```r
remotes::install_github("zyf0717/HeatStressR")
```

After installation:

```r
library(HeatStressR)
indexShow()
```

## Units and parameter reference

`indexShow()` lists each single-index calculation, its required inputs, and its
output unit. For detailed parameter definitions and units—including Liljegren
controls such as pressure, radiation, coordinates, timestamps, and direct
fraction—use the generated R help for the relevant function:

```r
?wbgt.Liljegren
?wbgt.Bernard
?heat_indices
```

## Quick start: Liljegren WBGT

`wbgt.Liljegren()` expects aligned vectors for air temperature (`tas`, °C),
dewpoint (`dewp`, °C), wind speed (`wind`, m/s), total downwelling shortwave
radiation (`radiation`, W/m²), and timestamps (`dates`). Longitude (`lon`,
degrees), latitude (`lat`, degrees), and pressure (`pressure`, hPa) may each be
a scalar or row-aligned vector.

```r
# `dates` is timezone-aware.
# `pressure_hpa` is optional; defaults to 1010 hPa for legacy compatibility.
# `direct_fraction` is direct / (direct + diffuse); defaults to 0.8.
# `solar_time` may be "timestamp" (default) or "date_noon".
# `engine` may be "batch" (default) or "scalar".

result <- wbgt.Liljegren(
  tas, dewp, wind, radiation, dates,
  lon = lon, lat = lat,
  pressure = pressure_hpa,
  direct_fraction = direct_fraction,
  solar_time = "timestamp",
  engine = "batch"
)
```

The result contains WBGT, globe temperature (`Tg`), and natural wet-bulb
temperature (`Tnwb`). Batch is the default engine; use scalar only for
reference comparisons or debugging. For a single very large call, set
`workers > 1` to use temporary local PSOCK workers; do not nest it inside an
existing parallel loop.

## Liljegren contract

HeatStressR evaluates aligned, instantaneous meteorological states. It does
not infer interval conventions or perform meteorological preprocessing. Use
timezone-aware `POSIXct` timestamps for high-throughput calls; ISO-8601
strings remain a convenience input.

`direct_fraction` accepts one value or a row-aligned vector and defaults to
`0.8`. Supply an externally derived value when direct and diffuse radiation
are available.

See the generated R help for the complete parameter reference:

```r
?wbgt.Liljegren
```

## Calculate multiple non-Liljegren indices

Use `heat_indices()` when several closed-form indices are needed for the same
observations. It validates the shared temperature and humidity vectors once and
calculates vapour pressure once for `swbgt`, `apparentTemp`, and `humidex`.
The default selection requires `wind`; request a subset when wind is not
available.

```r
indices <- heat_indices(tas, hurs, wind = wind)
humidex_and_hi <- heat_indices(tas, hurs, indices = c("humidex", "hi"))

# Bernard WBGT is opt-in and requires dew point. The returned column is WBGT;
# call wbgt.Bernard() directly when the psychrometric wet-bulb temperature is
# also needed.
shade_wbgt <- heat_indices(
  tas, hurs, dewp = dewp, indices = "wbgt.Bernard"
)
```

All output columns are in °C. Use `indexShow()` for the single-index input and
unit catalog.

## Guides

- [Liljegren inputs and scope](inst/doc/liljegren-inputs.md)
- [Parallel execution](inst/doc/parallelism.md)
- [Differences from the original C implementation](inst/doc/original-c-differences.md)
- [Benchmarking](inst/doc/benchmarking.md)
- [Non-Liljegren indices](inst/doc/non-liljegren-indices.md)
- [Documentation index](inst/doc/README.md)

## Fork scope

HeatStressR prioritizes scalable Liljegren WBGT and compatible improvements to
the remaining heat indices. It evaluates supplied meteorological states;
source-specific preprocessing, interval conventions, and wind-height
adjustment remain caller responsibilities.

Built-in process-level parallel execution is implemented only for
`wbgt.Liljegren()`. The other indices are vectorized where practical but run in
one R process. Users who need to parallelize those calculations should manage
independent locations, files, or partitions in their own workflow: see
[Parallel execution](inst/doc/parallelism.md) for guidance.
