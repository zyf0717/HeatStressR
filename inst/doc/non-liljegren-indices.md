# Non-Liljegren indices

`heat_indices()` calculates several closed-form indices from one aligned set
of air-temperature and relative-humidity observations. It returns a data frame
with one row per observation and columns in the requested order.

```r
all_indices <- heat_indices(tas, hurs, wind = wind)
thermal_only <- heat_indices(tas, hurs, indices = c("wbt", "humidex", "hi"))
```

The default request is `wbt`, `swbgt`, `apparentTemp`, `effectiveTemp`,
`humidex`, `discomInd`, and `hi`. `apparentTemp` and `effectiveTemp` require a
row-aligned `wind` vector. Every default output is in °C.

`wbgt.Bernard` is optional because it requires dew point and has a different
computational profile. Select it explicitly with a row-aligned `dewp` vector:

```r
shade_wbgt <- heat_indices(
  tas, hurs, dewp = dewp, indices = "wbgt.Bernard"
)
```

That column contains Bernard WBGT in °C. Call `wbgt.Bernard()` directly when
the psychrometric wet-bulb component (`Tpwb`) is also needed.

## Shared computation

For selected `swbgt`, `apparentTemp`, and `humidex` columns, the function
validates shared temperature/humidity inputs once and calculates vapour
pressure once. This reduces repeated work relative to independent calls. The
public `tashurs2vap.pres()` helper still clamps relative humidity above 100% to
100% for compatibility; index functions, including `heat_indices()`, reject
such inputs.

## Performance

Run the reproducible benchmark from the repository root:

```sh
BENCH_REPS=3 Rscript benchmarks/benchmark-non-liljegren.R
```

It compares legacy and optimized formulas across cool, mixed, and hot inputs
at 1 through 1,000,000 rows, including the fused workflow.
