# Solver benchmarks

These benchmarks validate this fork's solver behavior and performance. A
`baseline` is a fixed historical revision used only for comparison; it does not
identify a supported upstream dependency.

`benchmark-vectorization.R` compares corrected scalar and explicit batch WBGT
solver paths.

It reports, for every input size:

- median elapsed time;
- sampled allocation bytes from `Rprofmem` (allocations of at least 1 KiB);
- scalar/reference speedup;
- output-equivalence status and maximum absolute difference for WBGT, globe,
  and natural wet-bulb temperatures;
- count and positions of `NA` outputs for every component.

It covers `calZenith()`, scalar and batch `wbgt.Liljegren()`, scalar `fTg()`, scalar `fTnwb()`,
and `wbgt.Bernard()`.

The synthetic inputs are deterministic. Radiation is derived from positive solar
elevation (`850 * max(cos(zenith), 0)`) at the benchmark location, so nighttime
rows cannot carry solar forcing. They include hourly UTC timestamps across leap
and non-leap years, low and moderate winds, equal/below-air dew points, and
known missing meteorological rows.

Current Liljegren benchmarks use the public C-aligned defaults: surface albedo
`0.45`, globe diameter `0.0508 m`, and minimum wind speed `0.13 m/s`. Solar
geometry is calculated from the UTC timestamp plus benchmark latitude and
longitude; `gmt_offset` and `averaging_period` can instead reproduce the
original C local-standard-time midpoint convention.

Run from the package root:

```bash
Rscript benchmarks/benchmark-vectorization.R
```

Defaults:

- `calZenith()`: 100, 1,000, 10,000, and 87,600 rows;
- `wbgt.Liljegren()`: 100, 1,000, 10,000, and 87,600 rows;
- scalar solvers and `wbgt.Bernard()`: 1, 10, and 100 rows;
- three repetitions per size.

The current recorded default run is documented in
[`results/environment.md`](results/environment.md), with machine-readable
measurements in `results/vectorization-baseline.csv` and
`results/solver-baseline.csv`. Timings are platform-specific and should not be
used as capacity estimates for another machine.

Liljegren benchmarks can take substantial time because they deliberately retain the numerical solvers. Use environment variables to reduce a smoke run or adjust repetitions:

```bash
BENCH_REPS=1 CAL_ZENITH_SIZES=100 LILJEGREN_SIZES=10 SOLVER_SIZES=10 Rscript benchmarks/benchmark-vectorization.R
```

Set `BENCHMARK_OUTPUT_DIR` to write the two CSV result files. This is used only
when intentionally refreshing a recorded baseline; ordinary local runs and CI
do not modify the working tree.

```bash
BENCHMARK_OUTPUT_DIR=benchmarks/results Rscript benchmarks/benchmark-vectorization.R
```

The script exits non-zero if corrected scalar and batch outputs differ beyond
`1e-4`, if `NA` positions differ for any WBGT component, or if a scalar solver
returns a non-finite value.

`benchmark-liljegren-e2e.R` times complete corrected-scalar and explicit batch
calls in the same measured region. It records runtime, all three output
differences, fallback count, final residual, and `NA` alignment.
Its default sizes are 100, 1,000, 10,000, and 87,600 rows; the last represents
one year of hourly observations. Override them with `E2E_SIZES` when needed.

`benchmark-liljegren-parallel.R` compares explicit batch worker counts and
records startup-inclusive wall time, speedup, throughput, output/diagnostic
equivalence, `NA` alignment, fallback count, and final residual. Its default
sizes are 87,600, 250,000, 1,000,000, and 5,000,000 rows. It requires an
installed HeatStressR package because PSOCK workers load the installed
namespace; use a smaller smoke run as follows:

```bash
R CMD INSTALL .
LILJEGREN_PARALLEL_SIZES=1000 LILJEGREN_WORKERS=1,2 BENCH_REPS=1 \
  Rscript benchmarks/benchmark-liljegren-parallel.R
```

The worker list is filtered to the current system's logical CPU limit. This
benchmark does not imply automatic worker selection by `wbgt.Liljegren()`.

`benchmark-liljegren-workers-1-to-6x87600.R` measures scaling from one through
six workers with a fixed 87,600 rows per worker. Each row compares a repeated
input parallel run with the corresponding extrapolation of the same one-worker
87,600-row block:

```bash
R CMD INSTALL .
Rscript benchmarks/benchmark-liljegren-workers-1-to-6x87600.R
```

The 2026-07-21 Apple M2 Max sweep (macOS arm64, R 4.6.1) peaked at five
workers. Times are one measurement per configuration; rerun with repeated
measurements before treating small differences as durable:

| Workers | Total rows | Seconds | Estimated speedup |
| ---: | ---: | ---: | ---: |
| 1 | 87,600 | 1.100 | 1.00x |
| 2 | 175,200 | 1.597 | 1.38x |
| 3 | 262,800 | 1.779 | 1.85x |
| 4 | 350,400 | 2.083 | 2.11x |
| 5 | 438,000 | 2.289 | 2.40x |
| 6 | 525,600 | 2.752 | 2.40x |

All runs had zero fallback solves and maximum final residual `6.20e-06`.
The full data is in
[`results/liljegren-workers-1-to-6x87600.csv`](results/liljegren-workers-1-to-6x87600.csv).


`benchmark-liljegren-three-way.R` measures one arm of the baseline/current
comparison. Set `BENCHMARK_ROOT` to the checkout under test and
`BENCHMARK_ENGINE` to `pre`, `scalar`, or `batch`; the `pre` mode supports the
baseline API without an `engine` argument.

`benchmark-liljegren-unresolved.R` runs the deterministic 100,000-row dataset
with diagnostics enabled. It prints failure-reason tables and residual
summaries, and can write one row per unresolved component plus every
high-radiation/high-zenith solar-geometry flag with bracket and fallback
metadata:

```bash
BENCHMARK_OUTPUT=benchmarks/results/liljegren-unresolved.csv \
  Rscript benchmarks/benchmark-liljegren-unresolved.R
```

`benchmark-liljegren-tolerance-sensitivity.R` evaluates residual limits
`1e-4`, `3e-4`, `1e-3`, `3e-3`, and `1e-2` with `root_tolerance = 1e-6`.
It records acceptance, failure categories, residuals, baseline differences,
runtime, and batch fallback counts.
