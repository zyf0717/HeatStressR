# HeatStressR

[![R-CMD-check](https://github.com/zyf0717/HeatStressR/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/zyf0717/HeatStressR/actions/workflows/R-CMD-check.yaml)

> **Fork notice:** This repository is an independently maintained fork of
> [HeatStress at `f77a263`](https://github.com/anacv/HeatStress/tree/f77a263ba6820a79b7092518ff4376c787ac45b2).
> HeatStressR is not maintained by, or affiliated with, the original project or
> its authors.

This fork addresses the following solver and operability issues in the
inherited R package implementation:

- fragile globe-temperature energy-balance evaluation and fixed clipping
  limits;
- unresolved or silently partial Liljegren WBGT results;
- conflated root, residual, and dew-point tolerances;
- insufficient row-level diagnostics for invalid inputs and solver failures;
- avoidable overhead in solar-geometry and batch evaluation paths.

## What is `HeatStressR`?

**HeatStressR** is an R package for calculating heat-stress indices. It
maintains the [HeatStress](https://github.com/anacv/HeatStress) function
interface while adding explicit numerical controls and observability to the R
implementation of the Liljegren WBGT method. It is not intended to improve on
or supersede the original Liljegren program.

### Development version

Before CRAN acceptance, install the development version from GitHub:

```R
remotes::install_github("zyf0717/HeatStressR")
```

### R support

Calculations require R 3.4 or later. The test suite is supported from R 4.1,
which is pinned in CI alongside release, oldrel-1, and devel.

A list of all available indices and the atomic functions calculating them is printed on screen with:

```R
library(HeatStressR)
indexShow()
```

### Performance and solver scope

`calZenith()` now processes date vectors in one pass. `wbgt.Liljegren()`
precomputes aligned zenith angles by coordinate pair and reuses timestamp-only
solar terms for repeated instants. Its default is the scalar R heat-balance
solver; the vectorized batch solver is an explicit opt-in.

The 2.1.2 timestamp-cache E2E benchmark uses a 192-location, 129,024-row
hourly fixture and three repetitions on macOS arm64 with R 4.6.1:

| Mode | Rows | Coordinate pairs | Scalar | Batch | Speedup |
| --- | ---: | ---: | ---: | ---: | ---: |
| Fixed | 129,024 | 1 | 33.323 s | 1.357 s | 24.56x |
| Grouped | 129,024 | 192 | 33.556 s | 1.314 s | 25.54x |
| Unique | 129,024 | 129,024 | 36.074 s | 2.922 s | 12.35x |

All component NA positions aligned; no batch root required fallback; and the
largest scalar/batch component difference was `1.23e-6` °C. Full E2E and
PSOCK-worker results, raw CSVs, and reproduction commands are in the
[timestamp-cache benchmark report](benchmarks/results/liljegren-coordinate-aware-2.1.2.md).

### Selecting the Liljegren solver

```r
# Default scalar R solver
result <- wbgt.Liljegren(tas, dewp, wind, radiation, dates, lon = lon, lat = lat)

# Opt in to the vectorized solver
result_fast <- wbgt.Liljegren(
  tas, dewp, wind, radiation, dates, lon = lon, lat = lat, engine = "batch"
)
```

### Optional multicore batch execution

The batch engine remains single-process by default. Set `workers` explicitly
to use up to that many local PSOCK R processes. The effective count is capped
at the number of input rows, so small inputs do not launch empty workers.

```r
result_parallel <- wbgt.Liljegren(
  tas, dewp, wind, radiation, dates, lon = lon, lat = lat,
  engine = "batch", workers = 4
)
```

`workers` must be an integer between 1 and the currently permitted worker
count, normally the detected logical CPU count. R check environments that set
`_R_CHECK_LIMIT_CORES_` permit no more than two workers.
Each batch call creates and stops its own worker cluster. Worker startup and
data transfer can make small workloads slower; retain `workers = 1` when a
single process is preferable.
For `workers > 1`, the parent process computes aligned solar geometry once,
then workers preprocess contiguous pressure, forcing, dewpoint-policy, and
humidity chunks before solving and assembling local WBGT values.

The 2.1.2 grouped-coordinate worker sweep used the 192-location, 129,024-row
fixture with three repetitions on macOS arm64, R 4.6.1:

| Workers | Rows | Median | Speedup vs. 1 worker |
| ---: | ---: | ---: | ---: |
| 1 | 129,024 | 1.230 s | 1.00x |
| 2 | 129,024 | 1.125 s | 1.09x |
| 4 | 129,024 | 0.833 s | 1.48x |

All runs had aligned NA positions, identical numerical diagnostics after
worker-count metadata normalization, zero fallbacks, and maximum final
residual `8.69e-6`. Raw data and the E2E results are in the
[timestamp-cache benchmark report](benchmarks/results/liljegren-coordinate-aware-2.1.2.md).

### Input compatibility

The package is now named `HeatStressR`; replace
`library(HeatStress)` from [HeatStress](https://github.com/anacv/HeatStress)
with `library(HeatStressR)`. The public exports and legacy argument order are
retained relative to the pre-fork interface. Existing positional or named calls
to `calZenith()`, `fTg()`, `fTnwb()`, and `wbgt.Liljegren()` remain valid;
fork-specific options are trailing optional arguments. Standard date strings
and `POSIXct` inputs continue to work, while offset-aware ISO 8601 datetimes
are additionally supported.

### Liljegren physical and time controls

`pressure` accepts one value or a vector aligned with the meteorological rows;
the default is 1010 hPa. The C-aligned defaults are `surface_albedo = 0.45`,
`globe_diameter = 0.0508`, and `min_wind_speed = 0.13`.

Solar geometry uses latitude, longitude, and timestamp. `POSIXct`/`POSIXlt`
timestamps and ISO 8601 strings with an offset (for example,
`2024-06-01T20:00:00+08:00` or `2024-06-01T12:00:00Z`) identify instants and
are normalized to UTC when `hour = TRUE`. To reproduce the original C timing
convention for naive local-standard-time input, supply `gmt_offset` (`LST - GMT`)
and `averaging_period` in minutes; the solar position is evaluated at the interval
midpoint. Do not combine `gmt_offset` with an offset-bearing ISO 8601 string.

Input validation is deliberately stricter for the Liljegren path:

- meteorological vectors must be non-empty and have identical lengths, and
  `dates` must be row-aligned with them;
- `lon` and `lat` must be finite values in their geographic ranges, supplied
  either as scalars or vectors aligned with the meteorological rows. Repeated
  coordinate pairs share one solar-geometry calculation;
- `hour`, `noNAs`, `swap`, and `diagnostics` must be single, non-missing
  logical values; and
- tolerance controls and physical parameters must be finite and within their
  documented domains.

These rules reject malformed inputs that older versions of the inherited R
package could partly process or fail later. Input compatibility does not imply
numerical equivalence: R-package solar-geometry changes, C-aligned defaults,
and validated root solving can change results when legacy optional defaults
are omitted.

Use `diagnostics = TRUE` to inspect row-level solver status. Diagnostic vectors
always match the input length; `input_status` distinguishes filtered input rows
from attempted rows whose heat-balance solver failed.

`wbgt.Liljegren()` separates three numerical controls while retaining the
legacy `tolerance = 1e-4` behavior by default:

- `root_tolerance` controls root-location precision (default `1e-6 K`).
- `residual_tolerance` controls accepted absolute heat-balance residual
  (default `1e-4 K`; `0 < value <= 0.01`).
- `dewpoint_tolerance` controls the dewpoint-versus-air-temperature policy
  (default `1e-4 °C`).

Relaxing `residual_tolerance` only accepts an already located finite root; it
does not recover unbracketed or non-finite rows. WBGT remains `NA` unless both
Tg and Tnwb validate, while an independently validated component is retained.

The reproducible benchmark harness is available in the source repository:

```bash
Rscript benchmarks/benchmark-vectorization.R
Rscript benchmarks/benchmark-liljegren-unresolved.R
Rscript benchmarks/benchmark-liljegren-tolerance-sensitivity.R
```

It compares scalar and explicit batch paths in this R package,
reports median runtime and sampled allocations, and fails if values or `NA`
positions differ. End-to-end batch speedups are expected to be modest
because its numerical solvers remain the dominant cost. Batch diagnostics
separate batch, bracketing, and fallback evaluations and retain final signed
residuals for validation.

### Remaining differences from the original Liljegren C implementation

This fork implements the Liljegren heat-balance model, not a bitwise-compatible
port of the original C program. The comparison below is against the
[original C source](https://raw.githubusercontent.com/mdljts/wbgt/master/src/wbgt.c.original).
The differences describe this R package's behavior; they are expected and are
not a claim that HeatStressR improves on or supersedes the original Liljegren
implementation.

| Area | This fork | Original C program | Consequence |
| --- | --- | --- | --- |
| Wind-height adjustment | Accepts scalar or row-aligned pressure; supplied wind is assumed to be at the reference height. | Can transform wind from another height using stability, temperature gradient, and urban/rural inputs. | Adjust non-reference-height wind externally before calling the wrapper. |
| Solar geometry and time | Uses timestamp, latitude, longitude, equation of time, and optional C-style GMT-offset/midpoint handling. | Uses local standard time, GMT offset, input averaging period, and its own solar-position routine. | Time conventions can be matched, but the solar-position approximations are not bitwise-identical. |
| Irradiance partitioning | Retains supplied daytime radiation and assumes direct fraction `0.8`. | Caps irradiance against top-of-atmosphere solar flux and derives direct fraction from normalized irradiance. | Cloudy, miscalibrated, and near-horizon forcing can produce different Tg and Tnwb. |
| Root solving and failures | Uses adaptive bracketing, residual validation, `NA` failures, preserved valid components, and optional diagnostics/batch fallback. | Uses damped fixed-point iteration (50-iteration limit, `0.02 K` convergence test) and reports `-9999` when a component fails. | Numerical behavior, failure boundaries, and error outputs deliberately differ. |
| Output surface | Returns WBGT, Tg, and Tnwb. | Also returns psychrometric wet-bulb temperature and estimated wind speed. | The wrapper does not expose the full original-program output set. |

For cross-implementation validation, match pressure, wind height, time
convention, and radiation treatment. Agreement on a single weather series does
not establish interchangeability.
