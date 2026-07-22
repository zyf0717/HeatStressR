# HeatStressR

[![R-CMD-check](https://github.com/zyf0717/HeatStressR/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/zyf0717/HeatStressR/actions/workflows/R-CMD-check.yaml)

> **Fork notice:** HeatStressR is an independently maintained fork of
> [HeatStress at `f77a263`](https://github.com/anacv/HeatStress/tree/f77a263ba6820a79b7092518ff4376c787ac45b2).
> It is not maintained by, or affiliated with, the original project or its
> authors.

## What is HeatStressR?

HeatStressR calculates heat-stress indices in R, including the Liljegren WBGT
method. It preserves the inherited HeatStress public interface while adding
explicit numerical controls, validation, diagnostics, and an opt-in batch
solver. It is not intended to supersede the original Liljegren program.

## Install and load

HeatStressR requires R 3.4 or later. The test suite is supported from R 4.1;
CI also covers release, oldrel-1, and devel.

Install the current development version from GitHub:

```r
remotes::install_github("zyf0717/HeatStressR")
library(HeatStressR)
```

List the available indices and their atomic functions with:

```r
indexShow()
```

## Calculate Liljegren WBGT

`wbgt.Liljegren()` expects aligned vectors for air temperature (`tas`),
dewpoint (`dewp`), wind speed (`wind`), radiation (`radiation`), and timestamp
(`dates`). Longitude and latitude can each be a scalar or an aligned vector.

```r
# Default scalar R solver
result <- wbgt.Liljegren(
  tas, dewp, wind, radiation, dates, lon = lon, lat = lat
)

# Explicit opt-in to the vectorized batch solver
result_batch <- wbgt.Liljegren(
  tas, dewp, wind, radiation, dates, lon = lon, lat = lat,
  engine = "batch"
)
```

The result contains WBGT, globe temperature (`Tg`), and natural wet-bulb
temperature (`Tnwb`). The scalar engine is the default; select
`engine = "batch"` when processing a sufficiently large aligned data set.

## Compatibility with HeatStress

Replace `library(HeatStress)` with `library(HeatStressR)`. The public exports
and legacy argument order are retained relative to the pre-fork interface.
Existing positional or named calls to `calZenith()`, `fTg()`, `fTnwb()`, and
`wbgt.Liljegren()` remain accepted; fork-specific options are trailing
optional arguments.

Standard date strings and `POSIXct` inputs continue to work. Offset-aware ISO
8601 timestamps are additionally supported. Input compatibility does not mean
numerical equivalence: solar-geometry changes, C-aligned defaults, and
validated root solving can produce different results when legacy optional
defaults are omitted.

## Configure the Liljegren calculation

### Physical and time controls

`pressure` accepts one value or a vector aligned with the meteorological rows;
the default is 1010 hPa. The C-aligned defaults are `surface_albedo = 0.45`,
`globe_diameter = 0.0508`, and `min_wind_speed = 0.13`.

Solar geometry uses latitude, longitude, and timestamp. `POSIXct`/`POSIXlt`
timestamps and ISO 8601 strings with an offset—for example,
`2024-06-01T20:00:00+08:00` or `2024-06-01T12:00:00Z`—identify instants and
are normalized to UTC when `hour = TRUE`.

For naive local-standard-time input, use `gmt_offset` (`LST - GMT`) and
`averaging_period` in minutes to reproduce the original C timing convention:
the solar position is evaluated at the interval midpoint. Do not combine
`gmt_offset` with an offset-bearing ISO 8601 timestamp.

Inputs are deliberately validated before solving:

- meteorological vectors must be non-empty, equal length, and row-aligned with
  `dates`;
- `lon` and `lat` must be finite geographic coordinates, supplied as scalars
  or row-aligned vectors; repeated coordinate pairs share one solar-geometry
  calculation;
- `hour`, `noNAs`, `swap`, and `diagnostics` must be single, non-missing
  logical values; and
- tolerance controls and physical parameters must be finite and within their
  documented domains.

### Numerical controls and diagnostics

The legacy `tolerance = 1e-4` behavior remains the default.
`wbgt.Liljegren()` also separates three numerical controls:

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
  engine = "batch", workers = 4
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
  `engine = "batch", workers = 1L` within each task.

```r
results <- foreach::foreach(
  shard = weather_shards,
  .packages = "HeatStressR"
) %dopar% {
  wbgt.Liljegren(
    shard$tas, shard$dewp, shard$wind, shard$radiation, shard$dates,
    lon = shard$lon, lat = shard$lat, hour = TRUE,
    engine = "batch", workers = 1L
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
remains an explicit opt-in because numerical solvers dominate the end-to-end
cost and worker startup is material for small inputs.

The 2.1.2 timestamp-cache E2E benchmark used a 192-location, 129,024-row
hourly fixture with three repetitions on macOS arm64, R 4.6.1:

| Mode | Rows | Coordinate pairs | Scalar | Batch | Speedup |
| --- | ---: | ---: | ---: | ---: | ---: |
| Fixed | 129,024 | 1 | 33.323 s | 1.357 s | 24.56x |
| Grouped | 129,024 | 192 | 33.556 s | 1.314 s | 25.54x |
| Unique | 129,024 | 129,024 | 36.074 s | 2.922 s | 12.35x |

All component `NA` positions aligned; no batch root required fallback; and the
largest scalar/batch component difference was `1.23e-6` °C. The full E2E and
PSOCK-worker results, raw CSVs, and reproduction commands are in the
[timestamp-cache benchmark report](https://github.com/zyf0717/HeatStressR/blob/master/benchmarks/results/liljegren-coordinate-aware-2.1.2.md).

The 2.1.2 grouped-coordinate worker sweep used the same 192-location,
129,024-row fixture:

| Workers | Rows | Median | Speedup vs. 1 worker |
| ---: | ---: | ---: | ---: |
| 1 | 129,024 | 1.230 s | 1.00x |
| 2 | 129,024 | 1.125 s | 1.09x |
| 4 | 129,024 | 0.833 s | 1.48x |

These measurements predate the diagnostics-off worker-transfer optimization;
regenerate them before using them as current performance claims. The benchmark
policy and commands are documented in the
[benchmark README](https://github.com/zyf0717/HeatStressR/blob/master/benchmarks/README.md).

## Differences from the original Liljegren C implementation

This package implements the Liljegren heat-balance model; it is not a
bitwise-compatible port of the
[original C source](https://raw.githubusercontent.com/mdljts/wbgt/master/src/wbgt.c.original).
The following expected differences describe HeatStressR behavior and do not
claim it improves on or supersedes the original implementation.

| Area | HeatStressR | Original C program | Consequence |
| --- | --- | --- | --- |
| Wind-height adjustment | Accepts scalar or row-aligned pressure; supplied wind is assumed to be at the reference height. | Can transform wind from another height using stability, temperature gradient, and urban/rural inputs. | Adjust non-reference-height wind externally before calling the wrapper. |
| Solar geometry and time | Uses timestamp, latitude, longitude, equation of time, and optional C-style GMT-offset/midpoint handling. | Uses local standard time, GMT offset, input averaging period, and its own solar-position routine. | Time conventions can be matched, but the solar-position approximations are not bitwise-identical. |
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

This fork addresses inherited R-package implementation and operability issues:

- more robust globe-temperature energy-balance evaluation;
- explicit handling of unresolved or partial Liljegren results;
- independent root, residual, and dew-point tolerances;
- row-level diagnostics for invalid inputs and solver failures; and
- reduced solar-geometry and batch-evaluation overhead.
