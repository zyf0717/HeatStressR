#!/usr/bin/env Rscript

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
root <- normalizePath(if (length(script_arg)) {
  file.path(dirname(sub("^--file=", "", script_arg[1])), "..")
} else {
  getwd()
})
source(file.path(root, "benchmarks", "liljegren-benchmark-utils.R"))
suppressPackageStartupMessages(library(HeatStressR))

base_rows <- liljegren_parse_positive_integers("ROWS_PER_WORKER", 87600L)
if (length(base_rows) != 1L) stop("ROWS_PER_WORKER must be one positive integer")
worker_counts <- liljegren_parse_positive_integers("LILJEGREN_WORKERS", 1:6)
worker_counts <- unique(worker_counts[worker_counts <= HeatStressR:::max_liljegren_workers()])
if (!length(worker_counts) || worker_counts[1L] != 1L) worker_counts <- unique(c(1L, worker_counts))
modes <- liljegren_coordinate_modes("LILJEGREN_WORKER_COORDINATE_MODES", c("fixed", "grouped"))
dataset <- liljegren_dataset_path(root)

measure_batch <- function(weather, workers) {
  liljegren_measure(function() suppressWarnings(wbgt.Liljegren(
    weather$tas, weather$dewp, weather$wind, weather$radiation, weather$dates,
    lon = weather$lon, lat = weather$lat, hour = TRUE, engine = "batch",
    workers = workers, diagnostics = TRUE
  )), 1L)
}

rows <- lapply(modes, function(mode) {
  baseline_weather <- liljegren_workload(base_rows, mode = mode, path = dataset)
  baseline <- measure_batch(baseline_weather, workers = 1L)
  lapply(worker_counts, function(worker_count) {
    total_rows <- base_rows * worker_count
    weather <- if (worker_count == 1L) baseline_weather else
      liljegren_workload(total_rows, mode = mode, path = dataset)
    run <- if (worker_count == 1L) baseline else measure_batch(weather, worker_count)
    diagnostics <- run$value$diagnostics
    residuals <- liljegren_maximum_residual(diagnostics)
    data.frame(
      rows_per_worker = base_rows, total_rows = total_rows,
      requested_workers = worker_count, effective_workers = diagnostics$workers,
      liljegren_workload_metadata(weather),
      single_core_block_seconds = baseline$seconds,
      estimated_single_core_seconds = baseline$seconds * worker_count,
      parallel_seconds = run$seconds,
      estimated_speedup = baseline$seconds * worker_count / run$seconds,
      rows_per_second = total_rows / run$seconds,
      fallback_count = sum(diagnostics$Tg$used_fallback, na.rm = TRUE) +
        sum(diagnostics$Tnwb$used_fallback, na.rm = TRUE),
      max_final_residual = residuals,
      r_version = paste(R.version$major, R.version$minor, sep = "."),
      platform = R.version$platform,
      row.names = NULL
    )
  })
})
result <- do.call(rbind, unlist(rows, recursive = FALSE))
print(result, row.names = FALSE)
output <- Sys.getenv("BENCHMARK_OUTPUT", unset = "")
if (nzchar(output)) utils::write.csv(result, output, row.names = FALSE)
