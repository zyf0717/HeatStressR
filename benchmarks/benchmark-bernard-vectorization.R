#!/usr/bin/env Rscript

# Compare the legacy row-wise optimizer with the vectorized Bernard solver.
# BENCHMARK_ROOT selects the checkout; BENCH_REPS and BERNARD_ROWS override
# the default repetitions and comma-separated row counts.

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

legacy_wbgt_bernard <- function(tas, dewp, tolerance = 1e-4) {
  c1 <- 6.106
  c2 <- 17.27
  c3 <- 237.3
  c4 <- 1556
  c5 <- 1.484
  c6 <- 1010
  ed <- c1 * exp((c2 * dewp) / (c3 + dewp))
  residual <- function(Tpwb, tasi, edi) {
    abs(c4 * edi - c5 * edi * Tpwb - c4 * c1 * exp((c2 * Tpwb) / (c3 + Tpwb)) +
      c5 * c1 * exp((c2 * Tpwb) / (c3 + Tpwb)) * Tpwb + c6 * (tasi - Tpwb))
  }
  Tpwb <- vapply(seq_along(tas), function(i) {
    stats::optimize(
      residual, range(tas[i] + 1, dewp[i] - 1), tasi = tas[i], edi = ed[i],
      tol = tolerance
    )$minimum
  }, numeric(1))
  list(Tpwb = Tpwb, data = 0.67 * Tpwb + 0.33 * tas)
}

make_weather <- function(n) {
  index <- seq_len(n)
  phase <- 2 * pi * ((index - 1) %% 24) / 24
  tas <- 22 + 13 * sin(phase)
  list(tas = tas, dewp = tas - rep(c(1, 3, 6, 12, 20), length.out = n))
}

root <- Sys.getenv("BENCHMARK_ROOT", unset = getwd())
pkgload::load_all(root, quiet = TRUE)
sizes <- parse_sizes("BERNARD_ROWS", c(100L, 10000L, 100000L, 1000000L))
repetitions <- as.integer(Sys.getenv("BENCH_REPS", unset = "3"))
if (is.na(repetitions) || repetitions < 1L) stop("BENCH_REPS must be positive")

rows <- lapply(sizes, function(n) {
  weather <- make_weather(n)
  legacy <- measure(function() legacy_wbgt_bernard(weather$tas, weather$dewp), repetitions)
  vectorized <- measure(function() wbgt.Bernard(weather$tas, weather$dewp), repetitions)
  max_difference <- max(abs(legacy$value$Tpwb - vectorized$value$Tpwb))
  data.frame(
    rows = n, repetitions = repetitions,
    legacy_median_seconds = median(legacy$elapsed),
    vectorized_median_seconds = median(vectorized$elapsed),
    speedup = median(legacy$elapsed) / median(vectorized$elapsed),
    max_abs_tpwb_difference = max_difference,
    row.names = NULL
  )
})

result <- do.call(rbind, rows)
print(result, row.names = FALSE)
output <- Sys.getenv("BENCHMARK_OUTPUT", unset = "")
if (nzchar(output)) utils::write.csv(result, output, row.names = FALSE)
