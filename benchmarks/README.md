# Liljegren benchmarks

Three benchmark runners are retained.

| Runner | Comparison | Result |
| --- | --- | --- |
| `benchmark-liljegren-three-way.R` | Current batch and scalar engines versus pre-fork commit `f77a263ba6820a79b7092518ff4376c787ac45b2` | [`results/liljegren-three-way.md`](results/liljegren-three-way.md) |
| `benchmark-liljegren-workers.R` | One through six internal workers on one fixed workload | [`results/liljegren-parallel-2.1.6-1000000-unique-triplets.md`](results/liljegren-parallel-2.1.6-1000000-unique-triplets.md) |
| `benchmark-bernard-vectorization.R` | Legacy row-wise optimizer versus vectorized bisection | Prints results; set `BENCHMARK_OUTPUT` to save CSV. |

## Bernard vectorization

The runner uses identical, physically bracketed temperature/dew-point rows for
both implementations. It reports the median runtime, speedup, and maximum
absolute psychrometric wet-bulb difference for 100, 10,000, 100,000, and
1,000,000 rows by default.

```sh
BENCH_REPS=3 Rscript benchmarks/benchmark-bernard-vectorization.R
```

## Three-way comparison

Run the current batch and scalar arms from this checkout. Run the pre-fork arm
from a detached worktree at the recorded commit, then combine the three CSV
files by row count.

```sh
BENCHMARK_ROOT=$PWD BENCHMARK_ENGINE=batch BENCH_REPS=3 \
E2E_SIZES=100,1000,10000,100000 Rscript benchmarks/benchmark-liljegren-three-way.R

BENCHMARK_ROOT=$PWD BENCHMARK_ENGINE=scalar BENCH_REPS=3 \
E2E_SIZES=100,1000,10000,100000 Rscript benchmarks/benchmark-liljegren-three-way.R

git worktree add --detach /tmp/heatstressr-pre-fork f77a263ba6820a79b7092518ff4376c787ac45b2
BENCHMARK_ROOT=/tmp/heatstressr-pre-fork BENCHMARK_ENGINE=pre BENCH_REPS=3 \
E2E_SIZES=100,1000,10000,100000 Rscript benchmarks/benchmark-liljegren-three-way.R
```

## Worker comparison

The worker benchmark uses exactly 1,000,000 rows for every worker count.
It repeats 48 coordinate pairs but assigns each row a unique timestamp, so no
`(timestamp, lon, lat)` triplet repeats.

```sh
LILJEGREN_PARALLEL_ROWS=1000000 LILJEGREN_WORKERS=1,2,3,4,5,6 BENCH_REPS=3 \
  Rscript benchmarks/benchmark-liljegren-workers.R
```

Timed calls use `diagnostics = FALSE`; one untimed diagnostics call per worker
count validates numerical and diagnostic parity. The checked-in memory results
sum parent and worker RSS sampled at 50 ms; see the result record for details.
