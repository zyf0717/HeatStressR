#!/usr/bin/env Rscript

# Run one arm of the baseline/current Liljegren comparison. Set
# BENCHMARK_ROOT to the checkout being measured and BENCHMARK_ENGINE to one of
# pre, scalar, or batch. The baseline API does not accept `engine` or
# row-aligned coordinates, so this historical comparison intentionally remains
# a fixed-coordinate workload.

parse_sizes <- function(variable, defaults) {
  value <- Sys.getenv(variable, unset = "")
  if (!nzchar(value)) return(defaults)
  sizes <- suppressWarnings(as.integer(strsplit(value, ",", fixed = TRUE)[[1]]))
  if (any(is.na(sizes) | sizes < 1L)) stop(variable, " must be positive integers")
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

root <- Sys.getenv("BENCHMARK_ROOT", unset = getwd())
engine <- Sys.getenv("BENCHMARK_ENGINE", unset = "batch")
if (!engine %in% c("pre", "scalar", "batch")) stop("BENCHMARK_ENGINE must be pre, scalar, or batch")
pkgload::load_all(root, quiet = TRUE)

make_weather <- function(n, lon = -5.66, lat = 40.96) {
  index <- seq_len(n)
  phase <- 2 * pi * ((index - 1) %% 24) / 24
  dates <- as.POSIXct("2020-01-01 00:00:00", tz = "UTC") + (index - 1) * 3600
  zenith_degrees <- if (engine == "pre") {
    vapply(seq_along(dates), function(i) calZenith(dates[i], lon, lat, hour = TRUE), numeric(1))
  } else {
    calZenith(dates, lon, lat, hour = TRUE)
  }
  zenith <- degToRad(zenith_degrees)
  list(tas = 22 + 8 * sin(phase - pi / 2),
    dewp = 22 + 8 * sin(phase - pi / 2) - rep(c(0, 2, 4, 6), length.out = n),
    wind = rep(c(0, 0.05, 0.2, 0.8, 1.5, 2.5), length.out = n),
    radiation = 850 * pmax(cos(zenith), 0), dates = dates)
}

sizes <- parse_sizes("E2E_SIZES", c(100L, 1000L, 10000L, 100000L))
repetitions <- as.integer(Sys.getenv("BENCH_REPS", unset = "5"))
if (is.na(repetitions) || repetitions < 1L) stop("BENCH_REPS must be positive")

rows <- lapply(sizes, function(n) {
  weather <- make_weather(n)
  result <- measure(function() {
    args <- list(weather$tas, weather$dewp, weather$wind, weather$radiation,
      weather$dates, lon = -5.66, lat = 40.96, hour = TRUE)
    if (engine != "pre") args$engine <- engine
    suppressWarnings(do.call(wbgt.Liljegren, args))
  }, repetitions)
  data.frame(revision = if (engine == "pre") "pre_fork" else paste0("head_", engine),
    engine = engine, rows = n, repetitions = repetitions,
    coordinate_mode = "fixed", coordinate_pairs = 1L, rows_per_coordinate_pair = n,
    median_seconds = median(result$elapsed), na_data = sum(is.na(result$value$data)),
    na_Tg = sum(is.na(result$value$Tg)), na_Tnwb = sum(is.na(result$value$Tnwb)),
    row.names = NULL)
})

result <- do.call(rbind, rows)
print(result, row.names = FALSE)
output <- Sys.getenv("BENCHMARK_OUTPUT", unset = "")
if (nzchar(output)) utils::write.csv(result, output, row.names = FALSE)
