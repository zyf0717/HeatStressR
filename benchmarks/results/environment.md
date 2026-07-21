# Benchmark environment

- Captured: 2026-07-20T16:39:47+08:00
- Source commit: `02b038777309117e3ba99a987653f5c37773edfe`
- R: 4.3.3 (2024-02-29), `x86_64-pc-linux-gnu`
- Platform: Linux 6.17.0-40-generic, x86_64
- CPU: AMD Ryzen 7 7735HS with Radeon Graphics
- Repetitions: 5; each CSV reports median elapsed time and sampled allocation
  bytes (allocations of at least 1 KiB).

The deterministic synthetic datasets use hourly UTC timestamps, sinusoidal
22–30 °C air temperatures, dew points at or below air temperature, calm to
moderate winds, and 0–850 W/m² radiation. Vectorization inputs additionally
contain fixed missing-value positions. Solver fixtures use finite inputs only.

Command:

```sh
BENCH_REPS=5 CAL_ZENITH_SIZES=100,1000,10000 LILJEGREN_SIZES=10,100,1000 \
  SOLVER_SIZES=1,10,100 BENCHMARK_OUTPUT_DIR=benchmarks/results \
  Rscript benchmarks/benchmark-vectorization.R
```

`vectorization-baseline.csv` covers `calZenith()` and total
`wbgt.Liljegren()`. `solver-baseline.csv` covers scalar `fTg()`, scalar
`fTnwb()`, and total `wbgt.Bernard()`.
