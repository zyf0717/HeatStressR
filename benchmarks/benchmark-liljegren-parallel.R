#!/usr/bin/env Rscript

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
root <- normalizePath(if (length(script_arg)) {
  file.path(dirname(sub("^--file=", "", script_arg[1])), "..")
} else {
  getwd()
})
source(file.path(root, "benchmarks", "liljegren-benchmark-utils.R"))
suppressPackageStartupMessages(library(HeatStressR))

diagnostics_equal <- function(reference, candidate) {
  candidate$workers <- reference$workers
  candidate$requested_workers <- reference$requested_workers
  identical(reference, candidate)
}

sizes <- liljegren_parse_positive_integers("LILJEGREN_PARALLEL_SIZES",
  c(87600L, 250000L, 1000000L, 5000000L))
requested_workers <- liljegren_parse_positive_integers("LILJEGREN_WORKERS", c(1L, 2L, 4L, 8L))
workers <- unique(c(1L, requested_workers))
workers <- workers[workers <= HeatStressR:::max_liljegren_workers()]
if (!length(workers)) stop("No requested worker count is available on this system")
modes <- liljegren_coordinate_modes("LILJEGREN_PARALLEL_COORDINATE_MODES",
  c("fixed", "grouped"))
repetitions <- liljegren_parse_positive_integers("BENCH_REPS", 3L)
if (length(repetitions) != 1L) stop("BENCH_REPS must be one positive integer")
dataset <- liljegren_dataset_path(root)

rows <- lapply(modes, function(mode) lapply(sizes, function(n) {
  weather <- liljegren_workload(n, mode = mode, path = dataset)
  runs <- lapply(workers, function(worker_count) liljegren_measure(function() suppressWarnings(
    wbgt.Liljegren(
      weather$tas, weather$dewp, weather$wind, weather$radiation, weather$dates,
      lon = weather$lon, lat = weather$lat, hour = TRUE, engine = "batch",
      workers = worker_count, diagnostics = TRUE
    )
  ), repetitions))
  names(runs) <- as.character(workers)
  reference <- runs[["1"]]
  do.call(rbind, lapply(workers, function(worker_count) {
    candidate <- runs[[as.character(worker_count)]]
    comparison <- liljegren_compare_results(reference$value, candidate$value)
    data.frame(
      rows = n, requested_workers = worker_count,
      effective_workers = candidate$value$diagnostics$workers,
      repetitions = repetitions, liljegren_workload_metadata(weather),
      seconds = candidate$seconds, speedup_vs_one_worker = reference$seconds / candidate$seconds,
      rows_per_second = n / candidate$seconds,
      max_data_difference = comparison$max_data_difference,
      max_Tg_difference = comparison$max_Tg_difference,
      max_Tnwb_difference = comparison$max_Tnwb_difference,
      diagnostics_identical = diagnostics_equal(reference$value$diagnostics,
        candidate$value$diagnostics),
      na_aligned = comparison$na_aligned,
      fallback_count = sum(candidate$value$diagnostics$Tg$used_fallback, na.rm = TRUE) +
        sum(candidate$value$diagnostics$Tnwb$used_fallback, na.rm = TRUE),
      max_final_residual = liljegren_maximum_residual(candidate$value$diagnostics),
      row.names = NULL
    )
  }))
}))
result <- do.call(rbind, unlist(rows, recursive = FALSE))
print(result, row.names = FALSE)
output <- Sys.getenv("BENCHMARK_OUTPUT", unset = "")
if (nzchar(output)) utils::write.csv(result, output, row.names = FALSE)
if (!all(result$na_aligned) || !all(result$diagnostics_identical)) {
  stop("Parallel benchmark output or diagnostics diverged")
}
