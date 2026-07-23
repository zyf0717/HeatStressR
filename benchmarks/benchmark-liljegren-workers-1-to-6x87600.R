#!/usr/bin/env Rscript

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
root <- normalizePath(if (length(script_arg)) {
  file.path(dirname(sub("^--file=", "", script_arg[1])), "..")
} else {
  getwd()
})
source(file.path(root, "benchmarks", "liljegren-benchmark-utils.R"))
suppressPackageStartupMessages(library(HeatStressR))

total_rows <- liljegren_parse_positive_integers("LILJEGREN_PARALLEL_ROWS", 1000000L)
if (length(total_rows) != 1L)
  stop("LILJEGREN_PARALLEL_ROWS must be one positive integer")
worker_counts <- liljegren_parse_positive_integers("LILJEGREN_WORKERS", 1:6)
worker_counts <- unique(worker_counts[worker_counts <= HeatStressR:::max_liljegren_workers()])
if (!length(worker_counts) || worker_counts[1L] != 1L) worker_counts <- unique(c(1L, worker_counts))
modes <- liljegren_coordinate_modes("LILJEGREN_WORKER_COORDINATE_MODES", c("fixed", "grouped"))
repetitions <- liljegren_parse_positive_integers("BENCH_REPS", 3L)
if (length(repetitions) != 1L) stop("BENCH_REPS must be one positive integer")
dataset <- liljegren_dataset_path(root)

diagnostics_equal <- function(reference, candidate) {
  candidate$workers <- reference$workers
  candidate$requested_workers <- reference$requested_workers
  identical(reference, candidate)
}

measure_batch <- function(weather, workers) {
  liljegren_measure(function() suppressWarnings(wbgt.Liljegren(
    weather$tas, weather$dewp, weather$wind, weather$radiation, weather$dates,
    lon = weather$lon, lat = weather$lat, hour = TRUE, engine = "batch",
    workers = workers, diagnostics = FALSE
  )), repetitions)
}

inspect_batch <- function(weather, workers) suppressWarnings(wbgt.Liljegren(
  weather$tas, weather$dewp, weather$wind, weather$radiation, weather$dates,
  lon = weather$lon, lat = weather$lat, hour = TRUE, engine = "batch",
  workers = workers, diagnostics = TRUE
))$diagnostics

rows <- lapply(modes, function(mode) {
  weather <- liljegren_workload(total_rows, mode = mode, path = dataset)
  runs <- lapply(worker_counts, function(worker_count) {
    measure_batch(weather, workers = worker_count)
  })
  names(runs) <- as.character(worker_counts)
  diagnostic_runs <- lapply(worker_counts, function(worker_count) {
    inspect_batch(weather, workers = worker_count)
  })
  names(diagnostic_runs) <- as.character(worker_counts)
  baseline <- runs[["1"]]
  baseline_diagnostics <- diagnostic_runs[["1"]]
  lapply(worker_counts, function(worker_count) {
    run <- runs[[as.character(worker_count)]]
    diagnostics <- diagnostic_runs[[as.character(worker_count)]]
    comparison <- liljegren_compare_results(baseline$value, run$value)
    residuals <- liljegren_maximum_residual(diagnostics)
    data.frame(
      rows = total_rows,
      requested_workers = worker_count, effective_workers = diagnostics$workers,
      repetitions = repetitions,
      liljegren_workload_metadata(weather),
      seconds = run$seconds,
      speedup_vs_one_worker = baseline$seconds / run$seconds,
      rows_per_second = total_rows / run$seconds,
      max_data_difference = comparison$max_data_difference,
      max_Tg_difference = comparison$max_Tg_difference,
      max_Tnwb_difference = comparison$max_Tnwb_difference,
      diagnostics_identical = diagnostics_equal(baseline_diagnostics, diagnostics),
      na_aligned = comparison$na_aligned,
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
if (!all(result$na_aligned) || !all(result$diagnostics_identical)) {
  stop("Parallel benchmark output or diagnostics diverged")
}
