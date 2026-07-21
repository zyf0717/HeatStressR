#!/usr/bin/env Rscript

benchmark_root <- function() {
  script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  candidate <- if (length(script_arg)) {
    file.path(dirname(sub("^--file=", "", script_arg[1])), "..")
  } else {
    getwd()
  }
  normalizePath(candidate)
}

parse_sizes <- function(variable, defaults) {
  value <- Sys.getenv(variable, unset = "")
  if (!nzchar(value)) return(defaults)
  sizes <- suppressWarnings(as.integer(strsplit(value, ",", fixed = TRUE)[[1]]))
  if (any(is.na(sizes) | sizes < 1L)) stop(variable, " must be positive integers")
  sizes
}

make_weather <- function(n, lon = -5.66, lat = 40.96) {
  index <- seq_len(n)
  phase <- 2 * pi * ((index - 1) %% 24) / 24
  dates <- as.POSIXct("2020-01-01 00:00:00", tz = "UTC") + (index - 1) * 3600
  zenith <- HeatStressR:::degToRad(calZenith(dates, lon, lat, hour = TRUE))
  list(
    tas = 22 + 8 * sin(phase - pi / 2),
    dewp = 22 + 8 * sin(phase - pi / 2) - rep(c(0, 2, 4, 6), length.out = n),
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
  list(elapsed = elapsed, result = result)
}

root <- benchmark_root()
pkgload::load_all(root, quiet = TRUE)
sizes <- parse_sizes("E2E_SIZES", c(100L, 1000L, 10000L, 87600L))
repetitions <- as.integer(Sys.getenv("BENCH_REPS", unset = "5"))
label <- Sys.getenv("BENCHMARK_LABEL", unset = "c_aligned_defaults")
if (is.na(repetitions) || repetitions < 1L) stop("BENCH_REPS must be positive")

rows <- lapply(sizes, function(n) {
  weather <- make_weather(n)
  scalar <- measure(function() suppressWarnings(wbgt.Liljegren(
    weather$tas, weather$dewp, weather$wind, weather$radiation, weather$dates,
    lon = -5.66, lat = 40.96, hour = TRUE, engine = "scalar"
  )), repetitions)
  batch <- measure(function() suppressWarnings(wbgt.Liljegren(
    weather$tas, weather$dewp, weather$wind, weather$radiation, weather$dates,
    lon = -5.66, lat = 40.96, hour = TRUE, engine = "batch", diagnostics = TRUE
  )), repetitions)
  if (!all(vapply(batch$result[c("data", "Tnwb", "Tg")], length, integer(1)) == n))
    stop("Invalid output length")
  components <- c("data", "Tg", "Tnwb")
  same_na <- all(vapply(components, function(component) identical(
    is.na(scalar$result[[component]]), is.na(batch$result[[component]])
  ), logical(1)))
  max_difference <- vapply(components, function(component) {
    valid <- !is.na(scalar$result[[component]]) & !is.na(batch$result[[component]])
    if (any(valid)) max(abs(scalar$result[[component]][valid] -
      batch$result[[component]][valid])) else 0
  }, numeric(1))
  batch.diagnostics <- batch$result$diagnostics
  data.frame(
    revision = label,
    rows = n,
    repetitions = repetitions,
    scalar_seconds = median(scalar$elapsed),
    batch_seconds = median(batch$elapsed),
    speedup = median(scalar$elapsed) / median(batch$elapsed),
    max_data_difference = max_difference[["data"]],
    max_Tg_difference = max_difference[["Tg"]],
    max_Tnwb_difference = max_difference[["Tnwb"]],
    batch_fallback_count = sum(batch.diagnostics$Tg$used_fallback, na.rm = TRUE) +
      sum(batch.diagnostics$Tnwb$used_fallback, na.rm = TRUE),
    batch_max_final_residual = max(abs(c(batch.diagnostics$Tg$final_residual,
      batch.diagnostics$Tnwb$final_residual)), na.rm = TRUE),
    na_aligned = same_na,
    row.names = NULL
  )
})
result <- do.call(rbind, rows)
print(result, row.names = FALSE)
output <- Sys.getenv("BENCHMARK_OUTPUT", unset = "")
if (nzchar(output)) utils::write.csv(result, output, row.names = FALSE)
