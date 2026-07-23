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

HeatStressR requires R 3.4 or later. The test suite is supported from R 4.1.

```r
remotes::install_github("zyf0717/HeatStressR")
library(HeatStressR)
indexShow()
```

## Calculate Liljegren WBGT

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
reference comparisons or debugging.

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

## Guides

- [Liljegren inputs and scope](inst/doc/liljegren-inputs.md)
- [Parallel execution](inst/doc/parallelism.md)
- [Differences from the original C implementation](inst/doc/original-c-differences.md)
- [Benchmarking](inst/doc/benchmarking.md)
- [Documentation index](inst/doc/README.md)

## Fork scope

HeatStressR maintains an R implementation of the Liljegren model with
vectorized batch solving, optional PSOCK workers, configurable sensor and
radiation controls, timezone-aware solar geometry, and row-aligned solver
diagnostics.
