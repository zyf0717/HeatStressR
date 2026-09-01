#!/usr/bin/env Rscript

parse_sizes <- function(value, default) {
  if (!nzchar(value)) return(default)
  sizes <- suppressWarnings(as.integer(strsplit(value, ",", fixed = TRUE)[[1]]))
  if (any(is.na(sizes) | sizes < 1L)) stop("CARDINALITY_SIZES must be positive integers")
  sizes
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
  list(elapsed = elapsed, value = value)
}

make_case <- function(mode, n) {
  timestamp_count <- 24L
  timestamps <- as.POSIXct("2024-06-20 00:00:00", tz = "UTC") +
    seq.int(0, by = 3600, length.out = timestamp_count)
  dates <- rep(timestamps, length.out = n)
  if (mode == "fixed") {
    lon <- -5.66
    lat <- 40.96
  } else if (mode == "low") {
    coordinate <- rep(seq_len(100L), length.out = n)
    lon <- -179.5 + 359 * (coordinate - 1) / 99
    lat <- -89.5 + 179 * ((coordinate * 37L) %% 100L) / 99
  } else if (mode == "unique") {
    coordinate <- as.double(seq_len(n))
    lon <- -179.999 + 359.998 * (coordinate - 1) / max(1, n - 1)
    lat <- -89.999 + 179.998 * ((coordinate * 104729) %% n) / max(1, n - 1)
  } else {
    stop("CARDINALITY_MODE must be fixed, low, unique, or all")
  }
  list(dates = dates, lon = lon, lat = lat, timestamp_count = timestamp_count)
}

root <- Sys.getenv("BENCHMARK_ROOT", unset = getwd())
revision <- Sys.getenv("BENCHMARK_REVISION", unset = "current")
pkgload::load_all(root, quiet = TRUE)
sizes <- parse_sizes(Sys.getenv("CARDINALITY_SIZES", unset = ""), 100000L)
mode <- Sys.getenv("CARDINALITY_MODE", unset = "all")
modes <- if (mode == "all") c("fixed", "low", "unique") else mode
repetitions <- as.integer(Sys.getenv("BENCH_REPS", unset = "5"))
if (is.na(repetitions) || repetitions < 1L) stop("BENCH_REPS must be positive")

rows <- unlist(lapply(sizes, function(n) lapply(modes, function(case_mode) {
  input <- make_case(case_mode, n)
  result <- measure(function() HeatStressR:::calculate_liljegren_zenith(
    input$dates, input$lon, input$lat, hour = TRUE
  ), repetitions)
  data.frame(
    revision = revision, mode = case_mode, rows = n,
    timestamp_count = input$timestamp_count,
    coordinate_count = switch(case_mode, fixed = 1L, low = 100L, unique = n),
    repetitions = repetitions, median_seconds = median(result$elapsed),
    min_seconds = min(result$elapsed), max_seconds = max(result$elapsed),
    na_count = sum(is.na(result$value)), row.names = NULL
  )
})), recursive = FALSE)

result <- do.call(rbind, rows)
print(result, row.names = FALSE)
output <- Sys.getenv("BENCHMARK_OUTPUT", unset = "")
if (nzchar(output)) write.csv(result, output, row.names = FALSE)
