# Benchmarks

Five benchmark runners are retained.

| Runner | Comparison | Result |
| --- | --- | --- |
| `benchmark-liljegren-three-way.R` | Current batch and scalar engines versus pre-fork commit `f77a263ba6820a79b7092518ff4376c787ac45b2` | [`results/liljegren-three-way.md`](results/liljegren-three-way.md) |
| `benchmark-liljegren-workers.R` | One through six internal workers on one fixed workload | [`results/liljegren-parallel-2.1.6-1000000-unique-triplets.md`](results/liljegren-parallel-2.1.6-1000000-unique-triplets.md) |
| `benchmark-liljegren-coordinate-cardinality.R` | Isolated fixed, 100-coordinate, and unique-coordinate solar geometry with 24 repeated timestamps | [`results/liljegren-coordinate-cardinality-2.4.0.md`](results/liljegren-coordinate-cardinality-2.4.0.md) |
| `benchmark-bernard-vectorization.R` | Legacy row-wise optimizer versus vectorized bisection | Prints results; set `BENCHMARK_OUTPUT` to save CSV. |
| `benchmark-non-liljegren.R` | Legacy formulas versus optimized heat index, vapour pressure, dependents, and fused endpoint | Prints results; set `BENCHMARK_OUTPUT` to save CSV. |

## Non-Liljegren indices

This runner covers cool, mixed, and hot conditions at 1 through 1,000,000 rows.
It compares the legacy Rothfusz and vapour-pressure calculations with the
optimized paths, including the three vapour-pressure dependent indices and
the fused `heat_indices()` endpoint.

```sh
BENCH_REPS=3 Rscript benchmarks/benchmark-non-liljegren.R
```

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
BENCHMARK_ROOT=$PWD BENCHMARK_ENGINE=batch BENCHMARK_REVISION=heatstressr_2.4.0 \
BENCH_REPS=3 \
E2E_SIZES=100,1000,10000,100000 Rscript benchmarks/benchmark-liljegren-three-way.R

BENCHMARK_ROOT=$PWD BENCHMARK_ENGINE=scalar BENCHMARK_REVISION=heatstressr_2.4.0 \
BENCH_REPS=3 \
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

## Liljegren coordinate cardinality

The default run measures 100,000 rows with fixed, 100-coordinate, and unique
coordinate layouts. Every layout repeats the same 24 timestamps so timing
isolates coordinate projection. Add the 1,000,000-row size explicitly when
required. Run a single mode under `/usr/bin/time -v` to record peak RSS.

```sh
BENCHMARK_REVISION=heatstressr_2.4.0_vectorized BENCH_REPS=5 \
  Rscript benchmarks/benchmark-liljegren-coordinate-cardinality.R

BENCHMARK_REVISION=heatstressr_2.4.0_vectorized \
CARDINALITY_SIZES=1000000 CARDINALITY_MODE=unique BENCH_REPS=3 \
  /usr/bin/time -v Rscript benchmarks/benchmark-liljegren-coordinate-cardinality.R

git worktree add --detach /tmp/heatstressr-master-cardinality \
  41eca970a0649736d7b7c9633c59e7d8e19e3cf2
BENCHMARK_ROOT=/tmp/heatstressr-master-cardinality \
BENCHMARK_REVISION=master_grouped BENCH_REPS=5 \
  Rscript benchmarks/benchmark-liljegren-coordinate-cardinality.R

BENCHMARK_ROOT=/tmp/heatstressr-master-cardinality \
BENCHMARK_REVISION=master_grouped CARDINALITY_SIZES=1000000 \
CARDINALITY_MODE=unique BENCH_REPS=3 \
  /usr/bin/time -v Rscript benchmarks/benchmark-liljegren-coordinate-cardinality.R
```

## v3 canonical methods

`benchmark-v3.R` measures modern adapters, automatic/explicit bulk dispatch,
and the canonical Liljegren API. Set `V3_ROWS` and `BENCH_REPS`; optionally set
`BENCHMARK_OUTPUT` to a CSV path. Recorded results are in
[results/v3-3.0.0.md](results/v3-3.0.0.md).

The non-Liljegren runner uses an explicit seven-method subset for comparable
work. Heat Index differences against 2.x include intentional NWS corrections;
its old formula is a performance baseline, not a scientific oracle.
