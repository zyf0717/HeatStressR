# Three-way Liljegren benchmark

> Historical snapshot: this comparison predates the longitude-aware solar-time,
> C-aligned-default, and pressure-input changes. Use
> [`liljegren-e2e.md`](liljegren-e2e.md) for current scalar-versus-batch results.

This records complete `wbgt.Liljegren()` calls over the same deterministic
weather series at three revisions/engines:

- baseline: `f77a263ba6820a79b7092518ff4376c787ac45b2`;
- head scalar: `2f9e2d3` with `engine = "scalar"`;
- head batch: `2f9e2d3` with `engine = "batch"`.

Runtime was R 4.3.3 on Linux x86_64 (AMD Ryzen 7 7735HS), using the median of
five repetitions at 100, 1,000, 10,000, and 100,000 rows. The raw measurements are in
[`liljegren-three-way.csv`](liljegren-three-way.csv).

| Rows | Baseline | Head scalar | Head batch | Batch / scalar speedup |
| ---: | ---: | ---: | ---: | ---: |
| 100 | 0.056 s | 0.038 s | 0.005 s | 7.60x |
| 1,000 | 0.558 s | 0.383 s | 0.014 s | 27.36x |
| 10,000 | 5.896 s | 4.081 s | 0.124 s | 32.91x |
| 100,000 | 60.490 s | 41.860 s | 1.283 s | 32.63x |

The workload derives radiation from positive solar elevation. All three arms
produced finite Tg, Tnwb, and WBGT values for every benchmark row. The scalar
and batch head engines retain aligned output positions; their numerical
equivalence is covered by the end-to-end benchmark and test suite.

Reproduce each arm with the maintained runner. For the baseline, point
`BENCHMARK_ROOT` at a detached worktree for the reference commit:

```sh
BENCHMARK_ROOT=$PWD BENCHMARK_ENGINE=batch BENCH_REPS=5 \
  E2E_SIZES=100,1000,10000,100000 \
  Rscript benchmarks/benchmark-liljegren-three-way.R
```
