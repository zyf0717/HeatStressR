#!/usr/bin/env Rscript

# Fixed-workload internal worker benchmark. Every worker count receives the
# same input rows. Timestamps are unique while coordinate pairs repeat, so no
# (timestamp, longitude, latitude) triplet is repeated.

parse_positive_integers <- function(variable, defaults) {
  value <- Sys.getenv(variable, unset = "")
  if (!nzchar(value)) return(as.integer(defaults))
  parsed <- suppressWarnings(as.numeric(strsplit(value, ",", fixed = TRUE)[[1]]))
  if (any(is.na(parsed) | !is.finite(parsed) | parsed < 1 | parsed != floor(parsed)))
    stop(variable, " must contain positive integers")
  as.integer(parsed)
}

measure <- function(work, repetitions) {
  elapsed <- numeric(repetitions)
  value <- NULL
  for (i in seq_len(repetitions)) {
    gc()
    started <- proc.time()[["elapsed"]]
    value <- work()
    elapsed[i] <- proc.time()[["elapsed"]] - started
  }
  list(seconds = median(elapsed), value = value)
}

maximum_difference <- function(reference, candidate) {
  valid <- !is.na(reference) & !is.na(candidate)
  if (!any(valid)) return(0)
  max(abs(reference[valid] - candidate[valid]))
}

compare_results <- function(reference, candidate) {
  fields <- c("data", "Tg", "Tnwb")
  differences <- vapply(fields, function(field) {
    maximum_difference(reference[[field]], candidate[[field]])
  }, numeric(1))
  list(
    na_aligned = all(vapply(fields, function(field) identical(
      is.na(reference[[field]]), is.na(candidate[[field]])
    ), logical(1))),
    max_data_difference = differences[["data"]],
    max_Tg_difference = differences[["Tg"]],
    max_Tnwb_difference = differences[["Tnwb"]]
  )
}

diagnostics_equal <- function(reference, candidate) {
  candidate$workers <- reference$workers
  candidate$requested_workers <- reference$requested_workers
  identical(reference, candidate)
}

maximum_residual <- function(diagnostics) {
  values <- c(diagnostics$Tg$final_residual, diagnostics$Tnwb$final_residual)
  values <- values[is.finite(values)]
  if (!length(values)) return(NA_real_)
  max(abs(values))
}

make_weather <- function(n, coordinate_pairs = 48L) {
  index <- seq_len(n)
  coordinate_index <- rep(seq_len(coordinate_pairs), length.out = n)
  lon <- ((coordinate_index * 137.50776405003785) %% 360) - 180
  lat <- 80 * sin(coordinate_index * 0.6180339887498949)
  dates <- as.POSIXct("2000-01-01 00:00:00", tz = "UTC") +
    (index - 1) * 3600
  phase <- 2 * pi * ((index - 1) %% 24) / 24
  list(
    tas = 22 + 8 * sin(phase - pi / 2),
    dewp = 16 + 6 * sin(phase - pi / 2),
    wind = rep(c(0.05, 0.2, 0.8, 1.5, 2.5), length.out = n),
    radiation = 850 * pmax(sin(phase), 0),
    dates = dates, lon = lon, lat = lat,
    coordinate_pairs = coordinate_pairs
  )
}

suppressPackageStartupMessages(library(HeatStressR))

rows <- parse_positive_integers("LILJEGREN_PARALLEL_ROWS", 1000000L)
if (length(rows) != 1L) stop("LILJEGREN_PARALLEL_ROWS must be one positive integer")
worker_counts <- parse_positive_integers("LILJEGREN_WORKERS", 1:6)
worker_counts <- unique(worker_counts[worker_counts <= HeatStressR:::max_liljegren_workers()])
if (!length(worker_counts) || worker_counts[1L] != 1L) worker_counts <- unique(c(1L, worker_counts))
repetitions <- parse_positive_integers("BENCH_REPS", 3L)
if (length(repetitions) != 1L) stop("BENCH_REPS must be one positive integer")

weather <- make_weather(rows)
run <- function(workers, diagnostics) suppressWarnings(wbgt.Liljegren(
  weather$tas, weather$dewp, weather$wind, weather$radiation, weather$dates,
  lon = weather$lon, lat = weather$lat, hour = TRUE, engine = "batch",
  workers = workers, diagnostics = diagnostics
))

runs <- lapply(worker_counts, function(worker_count) {
  measure(function() run(worker_count, diagnostics = FALSE), repetitions)
})
names(runs) <- as.character(worker_counts)
diagnostic_runs <- lapply(worker_counts, function(worker_count) {
  run(worker_count, diagnostics = TRUE)$diagnostics
})
names(diagnostic_runs) <- as.character(worker_counts)
baseline <- runs[["1"]]
baseline_diagnostics <- diagnostic_runs[["1"]]

result <- do.call(rbind, lapply(worker_counts, function(worker_count) {
  candidate <- runs[[as.character(worker_count)]]
  diagnostics <- diagnostic_runs[[as.character(worker_count)]]
  comparison <- compare_results(baseline$value, candidate$value)
  data.frame(
    rows = rows, requested_workers = worker_count,
    effective_workers = diagnostics$workers, repetitions = repetitions,
    coordinate_mode = "timestamp_unique", coordinate_pairs = weather$coordinate_pairs,
    unique_timestamp_coordinate_triplets = rows,
    seconds = candidate$seconds,
    speedup_vs_one_worker = baseline$seconds / candidate$seconds,
    rows_per_second = rows / candidate$seconds,
    max_data_difference = comparison$max_data_difference,
    max_Tg_difference = comparison$max_Tg_difference,
    max_Tnwb_difference = comparison$max_Tnwb_difference,
    diagnostics_identical = diagnostics_equal(baseline_diagnostics, diagnostics),
    na_aligned = comparison$na_aligned,
    fallback_count = sum(diagnostics$Tg$used_fallback, na.rm = TRUE) +
      sum(diagnostics$Tnwb$used_fallback, na.rm = TRUE),
    max_final_residual = maximum_residual(diagnostics),
    r_version = paste(R.version$major, R.version$minor, sep = "."),
    platform = R.version$platform,
    row.names = NULL
  )
}))

print(result, row.names = FALSE)
output <- Sys.getenv("BENCHMARK_OUTPUT", unset = "")
if (nzchar(output)) utils::write.csv(result, output, row.names = FALSE)
if (!all(result$na_aligned) || !all(result$diagnostics_identical)) {
  stop("Parallel benchmark output or diagnostics diverged")
}
