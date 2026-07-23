# Parallel execution

Return to the [package README](https://github.com/zyf0717/HeatStressR#readme).

## In-package foreach workers

The batch engine is single-process by default. Set `workers` explicitly to
split one large `wbgt.Liljegren()` call across local `foreach`/PSOCK R processes. The
effective count is capped at the number of rows, so small inputs do not launch
empty workers.

```r
result_parallel <- wbgt.Liljegren(
  tas, dewp, wind, radiation, dates, lon = lon, lat = lat,
  solar_time = "timestamp", workers = 4
)
```

`workers` must be an integer between 1 and the currently permitted worker
count, normally the detected logical CPU count. R check environments that set
`_R_CHECK_LIMIT_CORES_` permit no more than two workers. Each batch call
creates and stops its own `doParallel` cluster, restoring any caller backend
afterward. Startup and transfer overhead can make small workloads slower, so
retain `workers = 1L` when a single process is preferable.

Workers calculate aligned solar zenith, then preprocess contiguous pressure,
forcing, dewpoint-policy, and humidity chunks before solving and assembling
local WBGT values.

## External `foreach` versus in-package workers

Use one parallel layer per calculation:

- Set `workers > 1` for one large `wbgt.Liljegren()` call. HeatStressR creates
  a temporary `doParallel` PSOCK backend and divides that call's rows.
- Use an external `foreach` backend for many independent locations, files, or
  time partitions. Its worker pool can remain alive across calls; set
  `workers = 1L` within each task.

```r
results <- foreach::foreach(
  shard = weather_shards,
  .packages = "HeatStressR"
) %dopar% {
  wbgt.Liljegren(
    shard$tas, shard$dewp, shard$wind, shard$radiation, shard$dates,
    lon = shard$lon, lat = shard$lat, solar_time = "timestamp",
    workers = 1L
  )
}
```

Do not use `workers > 1` inside an externally parallel `foreach` task unless
you deliberately provision nested worker pools. Nested processes oversubscribe
CPUs, multiply memory use, and repeatedly pay PSOCK startup and serialization
costs. HeatStressR must be installed on each external worker; `.packages`
loads it in the example above.
