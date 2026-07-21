#!/usr/bin/env Rscript

base_rows <- 87600L
workers <- 4L

make_weather_block <- function(n, lon = -5.66, lat = 40.96) {
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

measure_batch <- function(weather, workers) {
  gc()
  started <- proc.time()[["elapsed"]]
  result <- suppressWarnings(wbgt.Liljegren(
    weather$tas, weather$dewp, weather$wind, weather$radiation, weather$dates,
    lon = -5.66, lat = 40.96, hour = TRUE, engine = "batch", workers = workers,
    diagnostics = TRUE
  ))
  list(seconds = proc.time()[["elapsed"]] - started, result = result)
}

suppressPackageStartupMessages(library(HeatStressR))
maximum_workers <- HeatStressR:::max_liljegren_workers()
if (maximum_workers < workers)
  stop("This benchmark requires at least ", workers, " logical CPUs; detected ", maximum_workers)

block <- make_weather_block(base_rows)
single_core <- measure_batch(block, workers = 1L)
single_core_block_seconds <- single_core$seconds
rm(single_core)
gc()

weather <- lapply(block, rep, times = workers)
total_rows <- base_rows * workers
if (!all(vapply(weather, length, integer(1)) == total_rows))
  stop("Repeated benchmark inputs have inconsistent lengths")

parallel_run <- measure_batch(weather, workers)
result <- parallel_run$result
parallel_seconds <- parallel_run$seconds
if (!identical(result$diagnostics$workers, workers))
  stop("Benchmark did not retain the requested worker count")
if (!all(vapply(result[c("data", "Tg", "Tnwb")], length, integer(1)) == total_rows))
  stop("Benchmark returned inconsistent output lengths")

diagnostics <- result$diagnostics
residuals <- c(diagnostics$Tg$final_residual, diagnostics$Tnwb$final_residual)
residuals <- residuals[is.finite(residuals)]
estimated_single_core_seconds <- single_core_block_seconds * workers
summary <- data.frame(
  base_rows_per_worker = base_rows,
  total_rows = total_rows,
  requested_workers = workers,
  effective_workers = diagnostics$workers,
  single_core_block_seconds = single_core_block_seconds,
  estimated_single_core_seconds = estimated_single_core_seconds,
  parallel_seconds = parallel_seconds,
  estimated_speedup = estimated_single_core_seconds / parallel_seconds,
  rows_per_second = total_rows / parallel_seconds,
  fallback_count = sum(diagnostics$Tg$used_fallback, na.rm = TRUE) +
    sum(diagnostics$Tnwb$used_fallback, na.rm = TRUE),
  max_final_residual = if (length(residuals)) max(abs(residuals)) else NA_real_,
  r_version = paste(R.version$major, R.version$minor, sep = "."),
  platform = R.version$platform,
  row.names = NULL
)
print(summary, row.names = FALSE)
output <- Sys.getenv("BENCHMARK_OUTPUT", unset = "")
if (nzchar(output)) utils::write.csv(summary, output, row.names = FALSE)
