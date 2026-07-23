# Coordinate-aware Liljegren benchmarks

The Liljegren benchmark suite measures the public `wbgt.Liljegren()` path as
implemented in HeatStressR 2.1.6. Every current benchmark uses the shared
[`liljegren-benchmark-utils.R`](liljegren-benchmark-utils.R) workload contract
and reports these fields with its timing results:

- `coordinate_mode`: `fixed`, `grouped`, or `unique`;
- `coordinate_pairs`: distinct `(lon, lat)` pairs in the call; and
- `rows_per_coordinate_pair`: the reuse available to solar-geometry grouping.

`fixed` holds one coordinate pair for all rows. `grouped` preserves the
multi-location fixture’s pairs. `unique` assigns every row a distinct valid
coordinate pair. The modes distinguish the original fixed-station workload
from the new coordinate-grouping path and its no-reuse limit.

Benchmark setup—CSV loading, coordinate assignment, and radiation construction
from solar geometry—is outside the timed `wbgt.Liljegren()` call. Timings thus
measure wrapper preprocessing, grouped zenith evaluation with timestamp-term
reuse, and numerical solving. All scalar-versus-batch benchmarks fail when NA
locations differ or a component differs by more than `1e-4` °C.

Timed `wbgt.Liljegren()` calls use `diagnostics = FALSE`, matching the public
default. Runners that publish fallback, residual, or worker-diagnostic fields
perform a separate untimed `diagnostics = TRUE` call for validation.

## Parallel comparison contract

Every worker-count comparison holds the total number of input rows fixed. A
worker sweep therefore reports strong scaling for one workload; it never gives
additional workers additional rows. `rows` is identical across the worker
counts in each result group, and `speedup_vs_one_worker` uses that group's
one-worker measurement as its denominator.

## Datasets

[`data/liljegren-multi-location-e2e.csv`](data/liljegren-multi-location-e2e.csv)
contains 2,304 rows: 48 coordinate pairs × 48 hourly UTC observations.
[`data/liljegren-multi-location-28d.csv`](data/liljegren-multi-location-28d.csv)
contains 129,024 rows: 192 coordinate pairs × 28 days × 24 hours. Both use a
fixed seed and bounded weather fields. Regenerate either with:

```bash
Rscript benchmarks/generate-liljegren-multi-location-data.R

MULTI_LOCATION_LON_COUNT=24 \
MULTI_LOCATION_LATITUDES=-70,-50,-30,-10,10,30,50,70 \
MULTI_LOCATION_DAYS=28 \
MULTI_LOCATION_DATASET=benchmarks/data/liljegren-multi-location-28d.csv \
  Rscript benchmarks/generate-liljegren-multi-location-data.R
```

Set `LILJEGREN_BENCHMARK_DATASET` to use either fixture in any current
benchmark. The default is the 2,304-row fixture, repeated deterministically for
larger row counts.

## Runners

| Runner | Purpose | Default coordinate modes |
| --- | --- | --- |
| `benchmark-liljegren-e2e.R` | Scalar-versus-batch correctness and end-to-end timing | fixed, grouped, unique |
| `benchmark-liljegren-parallel.R` | Batch parallel-worker parity and throughput | fixed, grouped |
| `benchmark-liljegren-workers-1-to-6x87600.R` | Fixed-workload worker-count sweep | fixed, grouped |
| `benchmark-liljegren-tolerance-sensitivity.R` | Residual-tolerance behavior | grouped |
| `benchmark-liljegren-unresolved.R` | Failure and solar-geometry diagnostics | grouped |
| `benchmark-liljegren-zenith-unique.R` | Isolated zenith timing with unique or shared coordinates | unique, shared |
| `benchmark-vectorization.R` | Allocation/timing comparison plus component benchmarks | fixed, grouped, unique for Liljegren |
| `benchmark-liljegren-three-way.R` | Historical pre-fork comparison | fixed only |

The three-way benchmark cannot represent row-aligned coordinates because the
pre-fork API did not support them. It remains useful only as a fixed-location
historical reference.

## Commands

Smoke test all coordinate modes:

```bash
E2E_SIZES=100 E2E_COORDINATE_MODES=fixed,grouped,unique BENCH_REPS=1 \
  Rscript benchmarks/benchmark-liljegren-e2e.R
```

The current 2.1.2 timestamp-cache baseline is in
[`results/liljegren-coordinate-aware-2.1.2.md`](results/liljegren-coordinate-aware-2.1.2.md).
Refresh its full fixed/grouped E2E portion with:

```bash
LILJEGREN_BENCHMARK_DATASET=benchmarks/data/liljegren-multi-location-28d.csv \
E2E_SIZES=129024 E2E_COORDINATE_MODES=fixed,grouped BENCH_REPS=3 \
BENCHMARK_LABEL=heatstressr_2_1_2_timestamp_cache \
BENCHMARK_OUTPUT=benchmarks/results/liljegren-e2e-2.1.2-coordinate-aware.csv \
  Rscript benchmarks/benchmark-liljegren-e2e.R
```

Measure the no-reuse solar-geometry limit (129,024 unique hourly
timestamp-longitude-latitude triplets):

```bash
BENCH_REPS=3 \
BENCHMARK_OUTPUT=benchmarks/results/liljegren-zenith-unique-129024.csv \
  Rscript benchmarks/benchmark-liljegren-zenith-unique.R
```

For one shared coordinate pair across the same distinct hourly timestamps:

```bash
ZENITH_COORDINATE_MODE=shared BENCH_REPS=3 \
BENCHMARK_OUTPUT=benchmarks/results/liljegren-zenith-shared-129024.csv \
  Rscript benchmarks/benchmark-liljegren-zenith-unique.R
```

Parallel runners require an installed package because PSOCK workers load the
installed namespace:

```bash
R CMD INSTALL .
LILJEGREN_PARALLEL_SIZES=1000 LILJEGREN_WORKERS=1,2 BENCH_REPS=1 \
  Rscript benchmarks/benchmark-liljegren-parallel.R

LILJEGREN_PARALLEL_ROWS=1000000 LILJEGREN_WORKERS=1,2,4,6 BENCH_REPS=3 \
  Rscript benchmarks/benchmark-liljegren-workers-1-to-6x87600.R
```

## Historical results

Files in `results/` produced before this revamp are archival fixed-coordinate
recordings, not 2.1.2 multi-location performance baselines. Refresh results
with the runners above before citing current performance; record R version,
platform, dataset, coordinate modes, row counts, repetitions, and commit SHA
alongside any published timing table.

The checked-in Liljegren timing results also predate the diagnostics-off timing
policy. Regenerate them before comparing performance with this revision.
