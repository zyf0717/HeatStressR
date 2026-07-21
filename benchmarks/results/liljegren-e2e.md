# End-to-end Liljegren benchmark

This benchmark compares complete corrected-scalar and explicit batch
`wbgt.Liljegren()` calls, including solar geometry, input handling, globe and
natural-wet-bulb solving, and WBGT assembly.

- Configuration: longitude-aware solar time, C-aligned sensor defaults, and
  row-aligned pressure support
- Runtime: R 4.3.3, Linux x86_64, AMD Ryzen 7 7735HS
- Sizes: 100, 1,000, 10,000, and 87,600 rows
- Repetitions: three per size
- All three outputs (`data`, `Tg`, and `Tnwb`) have aligned `NA` positions.

Batch speedups over corrected scalar are 1.53x, 26.57x, 38.34x, and 40.10x at
100, 1,000, 10,000, and 87,600 rows respectively. Maximum absolute differences
remain below `1.3e-6` for WBGT, globe temperature, and natural wet-bulb
temperature. No rows required scalar fallback; final residuals remain below
`7.3e-6` for finite batch outputs.

Reproduce each revision with:

```sh
BENCH_REPS=3 BENCHMARK_LABEL=c_aligned_defaults BENCHMARK_OUTPUT=<result.csv> \
  Rscript benchmarks/benchmark-liljegren-e2e.R
```
