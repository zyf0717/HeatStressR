#!/usr/bin/env Rscript

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
root <- normalizePath(if (length(script_arg)) {
  file.path(dirname(sub("^--file=", "", script_arg[1])), "..")
} else {
  getwd()
})
source(file.path(root, "benchmarks", "liljegren-benchmark-utils.R"))
pkgload::load_all(root, quiet = TRUE)

sizes <- liljegren_parse_positive_integers("E2E_SIZES", c(100L, 1000L, 10000L, 87600L))
modes <- liljegren_coordinate_modes("E2E_COORDINATE_MODES")
repetitions <- liljegren_parse_positive_integers("BENCH_REPS", 3L)
if (length(repetitions) != 1L) stop("BENCH_REPS must be one positive integer")
label <- Sys.getenv("BENCHMARK_LABEL", unset = "coordinate_aware")
dataset <- liljegren_dataset_path(root)

rows <- lapply(modes, function(mode) lapply(sizes, function(n) {
  weather <- liljegren_workload(n, mode = mode, path = dataset)
  scalar <- liljegren_measure(function() suppressWarnings(wbgt.Liljegren(
    weather$tas, weather$dewp, weather$wind, weather$radiation, weather$dates,
    lon = weather$lon, lat = weather$lat, hour = TRUE, engine = "scalar"
  )), repetitions)
  batch <- liljegren_measure(function() suppressWarnings(wbgt.Liljegren(
    weather$tas, weather$dewp, weather$wind, weather$radiation, weather$dates,
    lon = weather$lon, lat = weather$lat, hour = TRUE, engine = "batch", diagnostics = TRUE
  )), repetitions)
  comparison <- liljegren_compare_results(scalar$value, batch$value)
  data.frame(
    revision = label, rows = n, repetitions = repetitions,
    liljegren_workload_metadata(weather),
    scalar_seconds = scalar$seconds, batch_seconds = batch$seconds,
    speedup = scalar$seconds / batch$seconds,
    max_data_difference = comparison$max_data_difference,
    max_Tg_difference = comparison$max_Tg_difference,
    max_Tnwb_difference = comparison$max_Tnwb_difference,
    batch_fallback_count = sum(batch$value$diagnostics$Tg$used_fallback, na.rm = TRUE) +
      sum(batch$value$diagnostics$Tnwb$used_fallback, na.rm = TRUE),
    batch_max_final_residual = liljegren_maximum_residual(batch$value$diagnostics),
    na_aligned = comparison$na_aligned,
    row.names = NULL
  )
}))
result <- do.call(rbind, unlist(rows, recursive = FALSE))
print(result, row.names = FALSE)

output <- Sys.getenv("BENCHMARK_OUTPUT", unset = "")
if (nzchar(output)) utils::write.csv(result, output, row.names = FALSE)
if (!all(result$na_aligned) || any(result[, c("max_data_difference", "max_Tg_difference",
  "max_Tnwb_difference")] > 1e-4)) {
  stop("Scalar and batch results diverged")
}
