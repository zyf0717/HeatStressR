# Parallel execution

Return to the [package README](https://github.com/zyf0717/HeatStressR#readme).

## In-package workers

The default batch engine runs in one R process. Set `workers` to split one
large `wbgt.Liljegren()` call into contiguous row chunks processed by local
`foreach`/`doParallel` PSOCK workers.

```r
result_parallel <- wbgt.Liljegren(
  tas, dewp, wind, radiation, dates, lon = lon, lat = lat,
  solar_time = "timestamp", engine = "batch", workers = 4L
)
```

The parent validates arguments, normalizes coordinates, partitions rows, and
reassembles results in input order. Each worker calculates solar zenith and
performs the complete chunk-local batch pipeline: forcing and dewpoint
preprocessing, humidity calculation, `Tg` and `Tnwb` solves, and WBGT
assembly. Repeated coordinate pairs reuse solar geometry within each worker;
there is no cross-worker coordinate cache.

`workers` must be an integer from 1 through the currently permitted logical
CPU count. The effective count is capped at the input-row count, avoiding
empty workers. R check environments with `_R_CHECK_LIMIT_CORES_ = "true"`
permit at most two workers. Each call creates and stops a temporary PSOCK
cluster, and restores the caller's registered `foreach` backend afterward.

Use `workers = 1L` for small calls or memory-constrained hosts: startup,
serialization, and per-process memory can outweigh parallel speedup. The
1,000,000-row reference workload reaches 4.35x speedup at six workers, while
peak combined parent-plus-worker RSS grows from 1.80 GiB (one worker) to 2.93
GiB. See [benchmark results](../../benchmarks/results/liljegren-parallel-2.1.6-1000000-unique-triplets.md).

## External `foreach` versus in-package workers

Use one parallel layer per calculation:

- Set `workers > 1L` for one large `wbgt.Liljegren()` call. HeatStressR owns
  a temporary backend and parallelizes that call end to end.
- Use a caller-managed `foreach` backend for many independent locations,
  files, or time partitions. Keep `workers = 1L` inside each task so that the
  outer pool stays alive across calls.

```r
library(foreach)

cluster <- parallel::makePSOCKcluster(6L)
doParallel::registerDoParallel(cluster)
on.exit(parallel::stopCluster(cluster), add = TRUE)

results <- foreach(
  shard = weather_shards,
  .packages = "HeatStressR"
) %dopar% {
  wbgt.Liljegren(
    shard$tas, shard$dewp, shard$wind, shard$radiation, shard$dates,
    lon = shard$lon, lat = shard$lat, solar_time = "timestamp",
    engine = "batch", workers = 1L
  )
}
```

Nested pools oversubscribe CPUs, multiply memory consumption, and repeatedly
pay process-start and serialization costs. Use nesting only when worker and
memory budgets have been explicitly provisioned.
