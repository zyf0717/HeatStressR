#!/usr/bin/env Rscript

parse_positive_integers <- function(variable, defaults) {
  value <- Sys.getenv(variable, unset = "")
  if (!nzchar(value)) return(defaults)
  parsed <- suppressWarnings(as.numeric(strsplit(value, ",", fixed = TRUE)[[1]]))
  if (any(is.na(parsed) | !is.finite(parsed) | parsed < 1 | parsed != floor(parsed)))
    stop(variable, " must contain positive integers")
  as.integer(parsed)
}

make_weather <- function(n, lon = -5.66, lat = 40.96) {
  index <- seq_len(n)
  phase <- 2 * pi * ((index - 1) %% 24) / 24
  dates <- as.POSIXct("2020-01-01 00:00:00", tz = "UTC") + (index - 1) * 3600
  zenith <- HeatStressR:::degToRad(calZenith(dates, lon, lat, hour = TRUE))
  list(
    tas = 22 + 8 * sin(phase - pi / 2),
    dewp = 16 + 6 * sin(phase - pi / 2),
    wind = rep(c(0, 0.05, 0.2, 0.8, 1.5, 2.5), length.out = n),
    radiation = 850 * pmax(cos(zenith), 0),
    dates = dates
  )
}

measure <- function(work, repetitions) {
  elapsed <- numeric(repetitions)
  result <- NULL
  for (i in seq_len(repetitions)) {
    gc()
    started <- proc.time()[["elapsed"]]
    result <- work()
    elapsed[i] <- proc.time()[["elapsed"]] - started
  }
  list(seconds = median(elapsed), result = result)
}

maximum_difference <- function(reference, candidate) {
  valid <- !is.na(reference) & !is.na(candidate)
  if (!any(valid)) return(0)
  max(abs(reference[valid] - candidate[valid]))
}

maximum_residual <- function(diagnostics) {
  values <- c(diagnostics$Tg$final_residual, diagnostics$Tnwb$final_residual)
  values <- values[is.finite(values)]
  if (!length(values)) return(NA_real_)
  max(abs(values))
}

diagnostics_equal <- function(reference, candidate) {
  candidate$workers <- reference$workers
  identical(reference, candidate)
}

suppressPackageStartupMessages(library(HeatStressR))
sizes <- parse_positive_integers("LILJEGREN_PARALLEL_SIZES",
  c(87600L, 250000L, 1000000L, 5000000L))
requested_workers <- parse_positive_integers("LILJEGREN_WORKERS", c(1L, 2L, 4L, 8L))
workers <- unique(c(1L, requested_workers))
workers <- workers[workers <= HeatStressR:::max_liljegren_workers()]
if (!length(workers)) stop("No requested worker count is available on this system")
repetitions <- parse_positive_integers("BENCH_REPS", 3L)
if (length(repetitions) != 1L) stop("BENCH_REPS must be one positive integer")

rows <- lapply(sizes, function(n) {
  weather <- make_weather(n)
  runs <- lapply(workers, function(worker_count) measure(function() suppressWarnings(
    wbgt.Liljegren(
      weather$tas, weather$dewp, weather$wind, weather$radiation, weather$dates,
      lon = -5.66, lat = 40.96, hour = TRUE, engine = "batch",
      workers = worker_count, diagnostics = TRUE
    )
  ), repetitions))
  names(runs) <- as.character(workers)
  reference <- runs[["1"]]
  do.call(rbind, lapply(workers, function(worker_count) {
    candidate <- runs[[as.character(worker_count)]]
    reference_result <- reference$result
    candidate_result <- candidate$result
    components <- c("data", "Tg", "Tnwb")
    data.frame(
      rows = n,
      requested_workers = worker_count,
      effective_workers = candidate_result$diagnostics$workers,
      repetitions = repetitions,
      seconds = candidate$seconds,
      speedup_vs_one_worker = reference$seconds / candidate$seconds,
      rows_per_second = n / candidate$seconds,
      max_data_difference = maximum_difference(reference_result$data, candidate_result$data),
      max_Tg_difference = maximum_difference(reference_result$Tg, candidate_result$Tg),
      max_Tnwb_difference = maximum_difference(reference_result$Tnwb, candidate_result$Tnwb),
      diagnostics_identical = diagnostics_equal(reference_result$diagnostics,
        candidate_result$diagnostics),
      na_aligned = all(vapply(components, function(component) identical(
        is.na(reference_result[[component]]), is.na(candidate_result[[component]])
      ), logical(1))),
      fallback_count = sum(candidate_result$diagnostics$Tg$used_fallback, na.rm = TRUE) +
        sum(candidate_result$diagnostics$Tnwb$used_fallback, na.rm = TRUE),
      max_final_residual = maximum_residual(candidate_result$diagnostics),
      row.names = NULL
    )
  }))
})
result <- do.call(rbind, rows)
print(result, row.names = FALSE)
output <- Sys.getenv("BENCHMARK_OUTPUT", unset = "")
if (nzchar(output)) utils::write.csv(result, output, row.names = FALSE)
