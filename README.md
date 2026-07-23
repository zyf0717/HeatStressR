# HeatStressR

[![R-CMD-check](https://github.com/zyf0717/HeatStressR/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/zyf0717/HeatStressR/actions/workflows/R-CMD-check.yaml)

> **Fork notice:** HeatStressR is an independently maintained fork of
> [HeatStress at `f77a263`](https://github.com/anacv/HeatStress/tree/f77a263ba6820a79b7092518ff4376c787ac45b2).
> It is not maintained by, or affiliated with, the original project or its
> authors.

## What is HeatStressR?

HeatStressR calculates heat-stress indices in R, including the Liljegren WBGT
method. Its Liljegren implementation provides vectorized batch solving,
explicit physical and numerical controls, input validation, and row-aligned
diagnostics. It is an R implementation of the Liljegren model, not a
bitwise-compatible port of the original C program.

## Install and load

HeatStressR requires R 3.4 or later. The test suite is supported from R 4.1;
CI also covers release, oldrel-1, and devel.

Install from GitHub:

```r
remotes::install_github("zyf0717/HeatStressR")
library(HeatStressR)
```

List the available indices and their atomic functions with:

```r
indexShow()
```

## Calculate Liljegren WBGT

`wbgt.Liljegren()` expects aligned vectors for air temperature (`tas`, °C),
dewpoint (`dewp`, °C), wind speed (`wind`, m/s), solar shortwave radiation
(`radiation`, W/m²), and timestamps (`dates`). Longitude (`lon`, degrees),
latitude (`lat`, degrees), and atmospheric pressure (`pressure`, hPa) may each
be a scalar or a vector aligned with the meteorological inputs.

```r
# Default vectorized batch solver
# `dates` should be timezone-aware when solar_time = "timestamp".
# `pressure_hpa` is measured atmospheric pressure in hPa.
result <- wbgt.Liljegren(
  tas, dewp, wind, radiation, dates,
  lon = lon, lat = lat,
  pressure = pressure_hpa,
  solar_time = "timestamp"
)

# Scalar reference solver
result_scalar <- wbgt.Liljegren(
  tas, dewp, wind, radiation, dates,
  lon = lon, lat = lat,
  pressure = pressure_hpa,
  solar_time = "timestamp",
  engine = "scalar"
)
```

The result contains WBGT, globe temperature (`Tg`), and natural wet-bulb
temperature (`Tnwb`). The vectorized batch engine is the default; select
`engine = "scalar"` for reference comparisons or debugging.

## Configure the Liljegren calculation

### Physical and time controls

`pressure` accepts one value or a vector aligned with the meteorological rows;
the default is 1010 hPa. Other defaults are `surface_albedo = 0.45`,
`globe_diameter = 0.0508`, and `min_wind_speed = 0.13`.

Solar geometry uses latitude, longitude, and timestamp. `POSIXct`/`POSIXlt`
timestamps and ISO 8601 strings with an offset—for example,
`2024-06-01T20:00:00+08:00` or `2024-06-01T12:00:00Z`—identify instants and
are normalized to UTC when `solar_time = "timestamp"`. For this recommended
timestamp mode, provide timezone-aware datetimes or convert local observations
to UTC before calling the function.

`averaging_period` optionally recenters interval observations before computing
solar position. It shifts each supplied timestamp backward by half the stated
interval; leave it at its default of `0` for instantaneous observations:

```r
# A 60-minute observation timestamped at 12:30 UTC is evaluated at 12:00 UTC.
result <- wbgt.Liljegren(
  tas, dewp, wind, radiation, utc_dates,
  lon = lon, lat = lat, pressure = pressure_hpa,
  solar_time = "timestamp",
  averaging_period = 60  # measurement interval, in minutes
)
```

Inputs are deliberately validated before solving:

- meteorological vectors must be non-empty, equal length, and row-aligned with
  `dates`;
- `lon` and `lat` must be finite geographic coordinates, supplied as scalars
  or row-aligned vectors; repeated coordinate pairs share one solar-geometry
  calculation;
- `solar_time = "timestamp"` uses each full timestamp, while
  `solar_time = "date_noon"` evaluates each date at 12:00 UTC; `noNAs`,
  `swap`, and `diagnostics` must be single, non-missing logical values; and
- tolerance controls and physical parameters must be finite and within their
  documented domains.

### Numerical controls and diagnostics

`wbgt.Liljegren()` exposes three numerical controls:

- `root_tolerance` controls root-location precision (default `1e-6 K`);
- `residual_tolerance` controls the accepted absolute heat-balance residual
  (default `1e-4 K`; `0 < value <= 0.01`); and
- `dewpoint_tolerance` controls the dewpoint-versus-air-temperature policy
  (default `1e-4 °C`).

Use `diagnostics = TRUE` when investigating invalid inputs or solver failures.
Diagnostic vectors always match the input length, and `input_status`
distinguishes filtered rows from rows whose heat-balance solver failed.
Diagnostics are disabled by default to avoid transferring row-level metadata
from PSOCK workers during normal batch calculations.

Relaxing `residual_tolerance` only accepts an already located finite root; it
does not recover unbracketed or non-finite rows. WBGT is `NA` unless both `Tg`
and `Tnwb` validate, while an independently validated component is retained.

## Scale a calculation

### In-package PSOCK workers

The batch engine is single-process by default. Set `workers` explicitly to
split one large `wbgt.Liljegren()` call across local PSOCK R processes. The
effective count is capped at the number of rows, so small inputs do not launch
empty workers.

```r
result_parallel <- wbgt.Liljegren(
  tas, dewp, wind, radiation, dates, lon = lon, lat = lat,
  solar_time = "timestamp", workers = 4
)
```

`workers` must be an integer between 1 and the currently permitted worker
count, normally the detected logical CPU count. R check environments that set
`_R_CHECK_LIMIT_CORES_` permit no more than two workers. Each batch call
creates and stops its own cluster; startup and transfer overhead can make
small workloads slower, so retain `workers = 1L` when a single process is
preferable.

The parent process computes aligned solar geometry once. Workers preprocess
contiguous pressure, forcing, dewpoint-policy, and humidity chunks before
solving and assembling local WBGT values.

### External `foreach` versus in-package workers

Use one parallel layer per calculation:

- Set `workers > 1` for one large `wbgt.Liljegren()` call. HeatStressR creates
  a temporary PSOCK cluster and divides that call's rows.
- Use an external `foreach` backend for many independent locations, files, or
  time partitions. Its worker pool can remain alive across calls; set
  `workers = 1L` within each task.

```r
results <- foreach::foreach(
  shard = weather_shards,
  .packages = "HeatStressR"
) %dopar% {
  wbgt.Liljegren(
    shard$tas, shard$dewp, shard$wind, shard$radiation, shard$dates,
    lon = shard$lon, lat = shard$lat, solar_time = "timestamp",
    workers = 1L
  )
}
```

Do not use `workers > 1` inside an externally parallel `foreach` task unless
you deliberately provision nested worker pools. Nested processes oversubscribe
CPUs, multiply memory use, and repeatedly pay PSOCK startup and serialization
costs. HeatStressR must be installed on each external worker; `.packages`
loads it in the example above.

## Performance and solver scope

`calZenith()` processes date vectors in one pass.
`wbgt.Liljegren()` precomputes aligned zenith angles by coordinate pair and
reuses timestamp-only solar terms for repeated instants. The batch engine
is the default because it vectorizes the dominant numerical solves. It remains
single-process unless `workers > 1`; PSOCK startup can still outweigh the
benefit of additional workers for small inputs.

Performance depends on input size, coordinate reuse, worker count, and local
hardware. Use the reproducible benchmark harness to measure the current
release on the target workload; its scenarios and commands are documented in
the [benchmark README](https://github.com/zyf0717/HeatStressR/blob/master/benchmarks/README.md).

## Differences from the original Liljegren C implementation

This package implements the Liljegren heat-balance model; it is not a
bitwise-compatible port of the
[original C source](https://raw.githubusercontent.com/mdljts/wbgt/master/src/wbgt.c.original).
The following expected differences describe HeatStressR behavior and do not
claim it improves on or supersedes the original implementation.

| Area | HeatStressR | Original C program | Consequence |
| --- | --- | --- | --- |
| Wind-height adjustment | Accepts scalar or row-aligned pressure; supplied wind is assumed to be at the reference height. | Can transform wind from another height using stability, temperature gradient, and urban/rural inputs. | Adjust non-reference-height wind externally before calling the wrapper. |
| Solar geometry and time | Uses timezone-aware timestamps, latitude, longitude, equation of time, and optional interval midpoint adjustment. | Uses local standard time, GMT offset, input averaging period, and its own solar-position routine. | Convert local observations to UTC or provide timezone-aware timestamps before calculation. |
| Irradiance partitioning | Retains supplied daytime radiation and assumes direct fraction `0.8`. | Caps irradiance against top-of-atmosphere solar flux and derives direct fraction from normalized irradiance. | Cloudy, miscalibrated, and near-horizon forcing can produce different `Tg` and `Tnwb`. |
| Root solving and failures | Uses adaptive bracketing, residual validation, `NA` failures, preserved valid components, and optional diagnostics/batch fallback. | Uses damped fixed-point iteration (50-iteration limit, `0.02 K` convergence test) and reports `-9999` when a component fails. | Numerical behavior, failure boundaries, and error outputs deliberately differ. |
| Output surface | Returns WBGT, `Tg`, and `Tnwb`. | Also returns psychrometric wet-bulb temperature and estimated wind speed. | The wrapper does not expose the full original-program output set. |

For cross-implementation validation, match pressure, wind height, time
convention, and radiation treatment. Agreement on one weather series does not
establish interchangeability.

## Benchmarking

The reproducible benchmark harness lives in the source repository. Timed
benchmarks use `diagnostics = FALSE`; diagnostic validation is run separately
when required.

```sh
Rscript benchmarks/benchmark-vectorization.R
Rscript benchmarks/benchmark-liljegren-e2e.R
Rscript benchmarks/benchmark-liljegren-parallel.R
Rscript benchmarks/benchmark-liljegren-tolerance-sensitivity.R
```

See the [benchmark documentation](https://github.com/zyf0717/HeatStressR/blob/master/benchmarks/README.md) for workload definitions, result locations,
and interpretation.

## Fork scope

HeatStressR maintains an R implementation of the Liljegren model with:

- vectorized batch solving and optional PSOCK workers;
- adaptive root bracketing, residual validation, and independent numerical
  tolerances;
- configurable pressure and sensor properties;
- timezone-aware solar geometry and interval midpoint adjustment; and
- row-aligned diagnostics for input filtering and solver failures.
