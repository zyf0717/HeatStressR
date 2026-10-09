# Parallel calculations

`wbgt_liljegren()` defaults to one process. Set `workers` explicitly for a large
call; temporary PSOCK workers compute ordered chunks and are stopped after
success or failure. The requested count is capped at the input row count and
must be within the detected logical CPU limit. R check core restrictions limit
requests to two workers.

```r
wbgt_liljegren(tas, dewp, wind_2m, radiation, time, lon, lat, workers = 2)
heat_indices(tas, hurs, dewp = dewp, wind_2m = wind_2m,
  radiation = radiation, time = time, lon = lon, lat = lat,
  indices = "wbgt_liljegren", liljegren_options = list(workers = 2))
```

Keep one parallel layer. When a workflow already parallelizes independent
files or locations, leave `workers = 1`. Other indices execute in one process;
parallelize independent partitions externally if needed. No automatic workload
heuristic changes the requested worker count.

Numeric values, missing masks, component values and diagnostic ordering match
single-process calculations. Diagnostics-off worker results contain compact
failure summaries; full row-level solver records are transferred only when
requested. Avoid requesting diagnostics for production runs that only need
WBGT values.

The scalar reference engine remains an internal scientific comparison/fallback
path and is accessible through the deprecated legacy API during migration.
