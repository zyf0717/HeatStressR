# Benchmarking

Return to the [package README](https://github.com/zyf0717/HeatStressR#readme).

`calZenith()` processes date vectors in one pass. The batch engine is the
default because it vectorizes the dominant numerical solves. It remains
single-process unless `workers > 1L`; then each temporary `foreach`/
`doParallel` PSOCK worker calculates zenith and runs the full chunk-local WBGT
pipeline.

Performance depends on input size, coordinate reuse, worker count, and local
hardware. Measure the current release on the target workload with the
reproducible harness:

```sh
Rscript benchmarks/benchmark-liljegren-three-way.R
Rscript benchmarks/benchmark-liljegren-workers.R
```

The worker-count benchmark holds total input rows fixed at 1,000,000 for every
comparison. It uses 48 repeated coordinate pairs and unique timestamps, so
every `(timestamp, lon, lat)` triplet is distinct. It measures strong scaling
across one through six parallel processes, reporting both elapsed time and
combined parent-plus-worker RSS rather than throughput under increasing work.

The three-way runner holds one coordinate pair fixed and likewise uses unique
timestamps. Its default row counts are 100, 1,000, 10,000, and 100,000; it
compares the pre-fork baseline, current scalar engine, and current batch
engine. The checked-in 100,000-row result is 44.826 s, 27.897 s, and 1.052 s,
respectively (26.52x batch/scalar speedup).

Timed benchmarks use `diagnostics = FALSE`; diagnostic validation is run
separately when required. See the [benchmark documentation](../../benchmarks/README.md)
for workload definitions, result locations, and interpretation.
