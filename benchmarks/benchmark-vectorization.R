#!/usr/bin/env Rscript

# Reproducible corrected-scalar versus vectorized-batch benchmark harness.

benchmark_root <- function() {
  script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(script_arg)) {
    return(normalizePath(file.path(dirname(sub("^--file=", "", script_arg[1])), "..")))
  }
  normalizePath(getwd())
}

parse_sizes <- function(variable, defaults) {
  value <- Sys.getenv(variable, unset = "")
  if (!nzchar(value)) return(defaults)
  sizes <- suppressWarnings(as.integer(strsplit(value, ",", fixed = TRUE)[[1]]))
  if (any(is.na(sizes) | sizes < 1L)) {
    stop(variable, " must be a comma-separated list of positive integers")
  }
  sizes
}

benchmark_repetitions <- function() {
  as.integer(Sys.getenv("BENCH_REPS", unset = "3"))
}

allocation_bytes <- function(profile_file) {
  lines <- readLines(profile_file, warn = FALSE)
  bytes <- suppressWarnings(as.numeric(sub("^([0-9]+).*", "\\1", lines)))
  sum(bytes, na.rm = TRUE)
}

measure <- function(work, repetitions, allocation_threshold = 1024L) {
  timings <- numeric(repetitions)
  allocations <- numeric(repetitions)
  value <- NULL

  for (i in seq_len(repetitions)) {
    gc()
    profile_file <- tempfile("heatstress-rprofmem-")
    Rprofmem(profile_file, threshold = allocation_threshold)
    started <- proc.time()[["elapsed"]]
    value <- work()
    timings[i] <- proc.time()[["elapsed"]] - started
    Rprofmem(NULL)
    allocations[i] <- allocation_bytes(profile_file)
    unlink(profile_file)
  }

  list(
    median_seconds = median(timings),
    median_allocation_bytes = median(allocations),
    value = value
  )
}

make_dates <- function(n) {
  as.POSIXct("2020-01-01 00:00:00", tz = "UTC") + (seq_len(n) - 1) * 3600
}

make_weather <- function(n, dates, lon = -5.66, lat = 40.96) {
  index <- seq_len(n)
  phase <- 2 * pi * ((index - 1) %% 24) / 24
  tas <- 22 + 8 * sin(phase - pi / 2)
  dewp <- tas - rep(c(0, 2, 4, 6), length.out = n)
  wind <- rep(c(0, 0.05, 0.2, 0.8, 1.5, 2.5), length.out = n)
  zenith <- HeatStressR:::degToRad(calZenith(dates, lon, lat, hour = TRUE))
  radiation <- 850 * pmax(cos(zenith), 0)

  missing_idx <- unique(pmin(n, c(13L, max(1L, n %/% 2), n)))
  tas[missing_idx[1]] <- NA_real_
  dewp[missing_idx[2]] <- NA_real_
  wind[missing_idx[3]] <- NA_real_

  list(tas = tas, dewp = dewp, wind = wind, radiation = radiation)
}

compare_numeric <- function(reference, candidate, tolerance) {
  same_na <- identical(is.na(reference), is.na(candidate))
  valid <- !is.na(reference) & !is.na(candidate)
  max_abs_difference <- if (any(valid)) max(abs(reference[valid] - candidate[valid])) else 0

  list(
    equivalent = same_na && max_abs_difference <= tolerance,
    max_abs_difference = max_abs_difference,
    na_count = sum(is.na(candidate)),
    na_positions = paste(which(is.na(candidate)), collapse = ",")
  )
}

benchmark_cal_zenith <- function(sizes, repetitions) {
  rows <- vector("list", length(sizes))

  for (j in seq_along(sizes)) {
    n <- sizes[j]
    dates <- make_dates(n)
    scalar <- measure(
      function() vapply(
        dates,
        reference_calZenith_scalar,
        numeric(1),
        lon = -5.66,
        lat = 40.96,
        hour = TRUE
      ),
      repetitions
    )
    vectorized <- measure(
      function() calZenith(dates, lon = -5.66, lat = 40.96, hour = TRUE),
      repetitions
    )
    comparison <- compare_numeric(scalar$value, vectorized$value, tolerance = 1e-12)

    rows[[j]] <- data.frame(
      benchmark = "calZenith",
      rows = n,
      scalar_seconds = scalar$median_seconds,
      vector_seconds = vectorized$median_seconds,
      speedup = scalar$median_seconds / vectorized$median_seconds,
      scalar_allocation_bytes = scalar$median_allocation_bytes,
      vector_allocation_bytes = vectorized$median_allocation_bytes,
      equivalent = comparison$equivalent,
      max_abs_difference = comparison$max_abs_difference,
      na_count = comparison$na_count,
      na_positions = comparison$na_positions,
      row.names = NULL
    )
  }

  do.call(rbind, rows)
}

benchmark_liljegren <- function(sizes, repetitions) {
  rows <- vector("list", length(sizes))

  for (j in seq_along(sizes)) {
    n <- sizes[j]
    dates <- make_dates(n)
    weather <- make_weather(n, dates)
    scalar <- measure(
      function() wbgt.Liljegren(
        weather$tas, weather$dewp, weather$wind, weather$radiation,
        dates, lon = -5.66, lat = 40.96, hour = TRUE, engine = "scalar"
      ),
      repetitions
    )
    batch <- measure(
      function() wbgt.Liljegren(
        weather$tas, weather$dewp, weather$wind, weather$radiation,
        dates, lon = -5.66, lat = 40.96, hour = TRUE, engine = "batch"
      ),
      repetitions
    )
    components <- c("data", "Tg", "Tnwb")
    comparisons <- stats::setNames(lapply(
      components,
      function(component) compare_numeric(scalar$value[[component]], batch$value[[component]], 1e-4)
    ), components)

    rows[[j]] <- data.frame(
      benchmark = "wbgt.Liljegren",
      rows = n,
      scalar_seconds = scalar$median_seconds,
      vector_seconds = batch$median_seconds,
      speedup = scalar$median_seconds / batch$median_seconds,
      scalar_allocation_bytes = scalar$median_allocation_bytes,
      vector_allocation_bytes = batch$median_allocation_bytes,
      equivalent = all(vapply(comparisons, `[[`, logical(1), "equivalent")),
      max_abs_difference = max(vapply(comparisons, `[[`, numeric(1), "max_abs_difference")),
      na_count = sum(vapply(comparisons, `[[`, numeric(1), "na_count")),
      na_positions = paste(
        vapply(
          names(comparisons),
          function(component) paste0(component, ":", comparisons[[component]]$na_positions),
          character(1)
        ),
        collapse = ";"
      ),
      row.names = NULL
    )
  }

  do.call(rbind, rows)
}

make_solver_weather <- function(n) {
  index <- seq_len(n)
  phase <- 2 * pi * ((index - 1) %% 24) / 24
  tas <- 26 + 6 * sin(phase - pi / 2)
  dewp <- tas - rep(c(1, 3, 5, 7), length.out = n)
  list(
    tas = tas,
    dewp = dewp,
    relh = dewp2hurs(tas, dewp),
    wind = rep(c(0.05, 0.2, 0.8, 1.5, 2.5), length.out = n),
    radiation = pmax(0, 850 * sin(phase)),
    zenith = pmin(1.52, pmax(0.1, abs(pi / 2 - phase)))
  )
}

benchmark_solvers <- function(sizes, repetitions) {
  rows <- vector("list", length(sizes) * 3L)
  row <- 0L

  for (n in sizes) {
    weather <- make_solver_weather(n)
    globe <- measure(
      function() vapply(
        seq_len(n),
        function(i) fTg(
          weather$tas[i], weather$relh[i], 1013.25, weather$wind[i], 0.1,
          weather$radiation[i], 0.8, weather$zenith[i]
        ),
        numeric(1)
      ),
      repetitions
    )
    natural_wet_bulb <- measure(
      function() vapply(
        seq_len(n),
        function(i) fTnwb(
          weather$tas[i], weather$dewp[i], weather$relh[i], 1013.25,
          weather$wind[i], 0.1, weather$radiation[i], 0.8, weather$zenith[i]
        ),
        numeric(1)
      ),
      repetitions
    )
    bernard <- measure(
      function() wbgt.Bernard(weather$tas, weather$dewp),
      repetitions
    )

    measurements <- list(
      fTg = globe,
      fTnwb = natural_wet_bulb,
      wbgt.Bernard = bernard
    )
    for (benchmark in names(measurements)) {
      row <- row + 1L
      measurement <- measurements[[benchmark]]
      value <- measurement$value
      finite <- if (is.list(value)) {
        all(vapply(value, function(component) all(is.finite(component)), logical(1)))
      } else {
        all(is.finite(value))
      }
      rows[[row]] <- data.frame(
        benchmark = benchmark,
        rows = n,
        median_seconds = measurement$median_seconds,
        median_allocation_bytes = measurement$median_allocation_bytes,
        valid_output = finite,
        row.names = NULL
      )
    }
  }

  do.call(rbind, rows)
}

write_benchmark_results <- function(output_dir, vectorization, solvers, repetitions) {
  if (!nzchar(output_dir)) return(invisible(NULL))

  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  vectorization$repetitions <- repetitions
  solvers$repetitions <- repetitions
  utils::write.csv(
    vectorization,
    file.path(output_dir, "vectorization-baseline.csv"),
    row.names = FALSE
  )
  utils::write.csv(
    solvers,
    file.path(output_dir, "solver-baseline.csv"),
    row.names = FALSE
  )
}

root <- benchmark_root()
pkgload::load_all(root, quiet = TRUE)
source(file.path(root, "tests", "testthat", "helper-reference-calZenith.R"))

cal_zenith_sizes <- parse_sizes("CAL_ZENITH_SIZES", c(100L, 1000L, 10000L, 87600L))
liljegren_sizes <- parse_sizes("LILJEGREN_SIZES", c(100L, 1000L, 10000L))
solver_sizes <- parse_sizes("SOLVER_SIZES", c(1L, 10L, 100L))
repetitions <- benchmark_repetitions()
if (is.na(repetitions) || repetitions < 1L) stop("BENCH_REPS must be a positive integer")

cat("HeatStressR vectorization benchmark\n")
cat("repetitions:", repetitions, "\n")
cat("allocation bytes: Rprofmem allocations >= 1024 bytes\n\n")

cal_zenith_results <- benchmark_cal_zenith(cal_zenith_sizes, repetitions)
liljegren_results <- benchmark_liljegren(liljegren_sizes, repetitions)
solver_results <- benchmark_solvers(solver_sizes, repetitions)

print(cal_zenith_results, row.names = FALSE)
cat("\n")
print(liljegren_results, row.names = FALSE)
cat("\n")
print(solver_results, row.names = FALSE)

write_benchmark_results(
  Sys.getenv("BENCHMARK_OUTPUT_DIR", unset = ""),
  rbind(cal_zenith_results, liljegren_results),
  solver_results,
  repetitions
)

if (!all(cal_zenith_results$equivalent) || !all(liljegren_results$equivalent) ||
    !all(solver_results$valid_output)) {
  stop("Benchmark output equivalence failed")
}
