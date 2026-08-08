# Parallel execution

Return to the [package README](https://github.com/zyf0717/HeatStressR#readme).

This guide applies only to `wbgt.Liljegren()`. It is the only HeatStressR
calculation with built-in process-level parallel execution. Other indices are
vectorized where practical but run in one R process. Users who need to
parallelize them should manage independent calls in their own workflow.

## In-package workers

The default batch engine runs in one R process. Set `workers` to split one
large `wbgt.Liljegren()` call into contiguous row chunks processed by local
base R PSOCK workers.

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
cluster without changing any caller-managed parallel backend.

Use `workers = 1L` for small calls or memory-constrained hosts: startup,
serialization, and per-process memory can outweigh parallel speedup. The
1,000,000-row reference workload reaches 4.35x speedup at six workers, while
peak combined parent-plus-worker RSS grows from 1.80 GiB (one worker) to 2.93
GiB. See [benchmark results](../../benchmarks/results/liljegren-parallel-2.1.6-1000000-unique-triplets.md).

## Caller-managed and in-package workers

Choose one parallel layer for each workload:

- Set `workers > 1L` only for one large `wbgt.Liljegren()` call. HeatStressR
  owns a temporary cluster and parallelizes that call end to end.
- Use a caller-managed parallel pool for independent locations, files, or
  time partitions. This pattern applies to every HeatStressR calculation,
  including `heat_indices()`, `wbgt.Bernard()`, and the individual indices.

Most non-Liljegren indices are already vectorized, but the performance tradeoff
between one call and external workers depends on vector length, partitioning,
serialization, and the execution environment. Benchmark representative data on
the target system before choosing an outer backend.

```r
cluster <- parallel::makePSOCKcluster(6L)
on.exit(parallel::stopCluster(cluster), add = TRUE)

results <- parallel::parLapply(cluster, weather_shards, function(shard) {
  HeatStressR::wbgt.Liljegren(
    shard$tas, shard$dewp, shard$wind, shard$radiation, shard$dates,
    lon = shard$lon, lat = shard$lat, solar_time = "timestamp",
    engine = "batch", workers = 1L
  )
})
```

The example uses `wbgt.Liljegren()`, but the task body can call any exported
HeatStressR function. When an outer task calls `wbgt.Liljegren()`, keep
`workers = 1L` inside it so the outer pool stays alive. Nested pools
oversubscribe CPUs, multiply memory consumption, and repeatedly pay process
startup and serialization costs. Use nesting only when worker and memory
budgets have been explicitly provisioned.
