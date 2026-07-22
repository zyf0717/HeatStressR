# Historical fixed-coordinate Liljegren benchmark

This historical benchmark compares complete corrected-scalar and explicit batch
`wbgt.Liljegren()` calls, including solar geometry, input handling, globe and
natural-wet-bulb solving, and WBGT assembly. Both recorded runs use one fixed
longitude-latitude pair for every row, so they do not measure row-aligned
coordinates or coordinate-grouping performance. They use
longitude-aware solar time, C-aligned sensor defaults, row-aligned pressure
support, 100, 1,000, 10,000, and 87,600 rows, and three repetitions per size.

All three outputs (`data`, `Tg`, and `Tnwb`) have aligned `NA` positions in
both runs. Maximum absolute differences remain below `1.3e-6` °C, no rows
required scalar fallback, and final residuals remain below `7.3e-6` for finite
batch outputs.

## AMD Ryzen 7 7735HS

R 4.3.3, Linux x86_64. Raw data:
[`liljegren-e2e.csv`](liljegren-e2e.csv).

| Rows | Scalar | Batch | Speedup |
| ---: | ---: | ---: | ---: |
| 100 | 0.118 s | 0.077 s | 1.53x |
| 1,000 | 0.372 s | 0.014 s | 26.57x |
| 10,000 | 4.026 s | 0.105 s | 38.34x |
| 87,600 | 36.451 s | 0.909 s | 40.10x |

## Apple M2 Max

R 4.6.1, macOS arm64. Raw data:
[`liljegren-e2e-m2-max.csv`](liljegren-e2e-m2-max.csv).

| Rows | Scalar | Batch | Speedup |
| ---: | ---: | ---: | ---: |
| 100 | 0.090 s | 0.057 s | 1.58x |
| 1,000 | 0.258 s | 0.014 s | 18.43x |
| 10,000 | 2.680 s | 0.107 s | 25.05x |
| 87,600 | 23.708 s | 0.932 s | 25.44x |

The historical generator has been superseded and these figures should be
treated as read-only. To run the new fixed-coordinate scenario (which uses the
current fixture and is not numerically comparable to this table), use the
coordinate-aware runner in [`../README.md`](../README.md):

```sh
E2E_COORDINATE_MODES=fixed BENCH_REPS=3 \
  BENCHMARK_OUTPUT=benchmarks/results/liljegren-e2e-current-fixed.csv \
  Rscript benchmarks/benchmark-liljegren-e2e.R
```
