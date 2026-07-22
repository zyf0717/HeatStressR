# HeatStressR 2.1.2 timestamp-cache Liljegren benchmark

Recorded 2026-07-22 on macOS arm64 (`aarch64-apple-darwin25.4.0`) with R
4.6.1. The E2E workload uses
`data/liljegren-multi-location-28d.csv`: 129,024 rows from 192 coordinate
pairs over 28 days at hourly frequency. Timings are medians of three runs;
fixture preparation is outside the measured `wbgt.Liljegren()` call.

## Scalar versus batch E2E

| Mode | Rows | Coordinate pairs | Scalar | Batch | Speedup |
| --- | ---: | ---: | ---: | ---: | ---: |
| Fixed | 129,024 | 1 | 33.323 s | 1.357 s | 24.56x |
| Grouped | 129,024 | 192 | 33.556 s | 1.314 s | 25.54x |
| Unique | 10,000 | 10,000 | 2.685 s | 0.248 s | 10.83x |

All scalar/batch component NA positions aligned, no batch roots required
fallback, and the largest component difference was `1.24e-6` °C. The
unique-coordinate case is deliberately bounded at 10,000 rows: constructing a
solar-consistent input requires one public solar-geometry call per unique pair,
which is excluded from the measured wrapper time but should not dominate a
routine release benchmark.

Raw data:
[`liljegren-e2e-2.1.2-coordinate-aware.csv`](liljegren-e2e-2.1.2-coordinate-aware.csv)
and [`liljegren-e2e-2.1.2-unique.csv`](liljegren-e2e-2.1.2-unique.csv).

## Grouped-coordinate PSOCK scaling

| Workers | Rows | Coordinate pairs | Median | Speedup vs. 1 worker |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 129,024 | 192 | 1.230 s | 1.00x |
| 2 | 129,024 | 192 | 1.125 s | 1.09x |
| 4 | 129,024 | 192 | 0.833 s | 1.48x |

Every worker count had identical numerical diagnostics after normalizing only
worker-count metadata, aligned NA positions, zero fallbacks, and maximum final
residual `8.69e-6`. Raw data:
[`liljegren-parallel-2.1.2-coordinate-aware.csv`](liljegren-parallel-2.1.2-coordinate-aware.csv).

## Reproduction

```sh
LILJEGREN_BENCHMARK_DATASET=benchmarks/data/liljegren-multi-location-28d.csv \
E2E_SIZES=129024 E2E_COORDINATE_MODES=fixed,grouped BENCH_REPS=3 \
BENCHMARK_LABEL=heatstressr_2_1_2_timestamp_cache \
BENCHMARK_OUTPUT=benchmarks/results/liljegren-e2e-2.1.2-coordinate-aware.csv \
  Rscript benchmarks/benchmark-liljegren-e2e.R

E2E_SIZES=10000 E2E_COORDINATE_MODES=unique BENCH_REPS=3 \
BENCHMARK_LABEL=heatstressr_2_1_2_timestamp_cache \
BENCHMARK_OUTPUT=benchmarks/results/liljegren-e2e-2.1.2-unique.csv \
  Rscript benchmarks/benchmark-liljegren-e2e.R
```
