# Benchmarking

The maintained runners in `benchmarks/` compare fixed workloads and validate
numerical results outside timed sections. `benchmark-v3.R` measures the modern
Romps/Lu adapters, automatic/explicit bulk dispatch, and canonical Liljegren
WBGT. Use `V3_ROWS` and `BENCH_REPS` to select realistic workloads.

Historical Liljegren runners retain the legacy adapter intentionally for
2.x/pre-fork comparisons and scalar/batch parity. The non-Liljegren runner uses
an explicit comparable index set; automatic v3 selection calculates additional
methods and cannot be compared as if it were the same workload.

```sh
V3_ROWS=10000,100000 BENCH_REPS=3 Rscript benchmarks/benchmark-v3.R
NON_LILJEGREN_ROWS=10000 BENCH_REPS=3 Rscript benchmarks/benchmark-non-liljegren.R
```

Record R/dependency versions, hardware, row count, inputs, controls, requested
workers and whether diagnostics were enabled. Do not compare implementations
without matching their physical assumptions. Published numerical accuracy is
separate from implementation parity and runtime performance.
