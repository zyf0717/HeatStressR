#!/usr/bin/env Rscript

# Benchmark non-Liljegren kernels against their pre-optimization formulas.
# Override NON_LILJEGREN_ROWS and BENCH_REPS to control the workload.

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
  list(seconds = median(elapsed), value = value)
}

legacy_vapour_pressure <- function(tas, hurs) {
  tas <- 10 * tas
  hurs[hurs > 100] <- 100
  result <- rep(NA, length(tas))
  ice <- which(tas < 0)
  water <- which(tas >= 0)
  result[water] <- hurs[water] * 0.06107 * exp(17.368 * tas[water] /
    (2388.3 + tas[water]))
  result[ice] <- hurs[ice] * 0.06108 * exp(17.856 * tas[ice] /
    (2455.2 + tas[ice]))
  result
}

legacy_hi <- function(tas, hurs) {
  tasf <- tas * 1.8 + 32
  simple <- 0.5 * (tasf + 61 + (tasf - 68) * 1.2 + hurs * 0.094)
  result <- -42.379 + 2.04901523 * tasf + 10.14333127 * hurs -
    0.22475541 * tasf * hurs - 6.83783e-3 * tasf ^ 2 -
    5.481717e-2 * hurs ^ 2 + 1.22874e-3 * tasf ^ 2 * hurs +
    8.5282e-4 * tasf * hurs ^ 2 - 1.99e-6 * tasf ^ 2 * hurs ^ 2
  low <- !is.na(tasf) & tasf >= 80 & tasf <= 112 & hurs <= 13
  high <- !is.na(tasf) & tasf >= 80 & tasf <= 87 & hurs > 85
  use_simple <- !is.na(tasf) & (tasf < 80 | (simple + tasf) / 2 < 80)
  result[low] <- result[low] - (13 - hurs[low]) / 4 * sqrt(
    17 - abs(tasf[low] - 95) / 17
  )
  result[high] <- result[high] + (hurs[high] - 85) / 10 * ((87 - tasf[high]) / 5)
  result[use_simple] <- simple[use_simple]
  (result - 32) / 1.8
}

make_weather <- function(n, climate) {
  index <- seq_len(n)
  phase <- 2 * pi * ((index - 1) %% 365) / 365
  tas <- switch(climate,
    cool = 8 + 7 * sin(phase),
    mixed = 20 + 15 * sin(phase),
    hot = 31 + 6 * sin(phase)
  )
  list(tas = tas, hurs = rep(c(10, 30, 50, 70, 90), length.out = n),
    wind = rep(c(0.5, 1, 2, 4), length.out = n))
}

root <- Sys.getenv("BENCHMARK_ROOT", unset = getwd())
pkgload::load_all(root, quiet = TRUE)
sizes <- parse_sizes("NON_LILJEGREN_ROWS", c(1L, 100L, 10000L, 100000L, 1000000L))
repetitions <- as.integer(Sys.getenv("BENCH_REPS", unset = "3"))
if (is.na(repetitions) || repetitions < 1L) stop("BENCH_REPS must be positive")

measure_pair <- function(name, legacy, optimized, rows, climate) {
  reference <- measure(legacy, repetitions)
  current <- measure(optimized, repetitions)
  reference_values <- unlist(reference$value, use.names = FALSE)
  current_values <- unlist(current$value, use.names = FALSE)
  data.frame(path = name, climate = climate, rows = rows, repetitions = repetitions,
    legacy_seconds = reference$seconds, optimized_seconds = current$seconds,
    speedup = reference$seconds / current$seconds,
    max_abs_difference = max(abs(reference_values - current_values), na.rm = TRUE),
    row.names = NULL)
}

results <- unlist(lapply(sizes, function(n) {
  unlist(lapply(c("cool", "mixed", "hot"), function(climate) {
    weather <- make_weather(n, climate)
    list(
      measure_pair("hi", function() legacy_hi(weather$tas, weather$hurs),
        function() hi(weather$tas, weather$hurs), n, climate),
      measure_pair("vapour_pressure", function() legacy_vapour_pressure(weather$tas, weather$hurs),
        function() tashurs2vap.pres(weather$tas, weather$hurs), n, climate),
      measure_pair("apparentTemp", function() weather$tas + 0.33 *
          legacy_vapour_pressure(weather$tas, weather$hurs) - 0.7 * weather$wind - 4,
        function() apparentTemp(weather$tas, weather$hurs, weather$wind), n, climate),
      measure_pair("humidex", function() weather$tas + 5 / 9 *
          (legacy_vapour_pressure(weather$tas, weather$hurs) - 10),
        function() humidex(weather$tas, weather$hurs), n, climate),
      measure_pair("swbgt", function() 0.567 * weather$tas + 0.216 *
          legacy_vapour_pressure(weather$tas, weather$hurs) + 3.38,
        function() swbgt(weather$tas, weather$hurs), n, climate),
      measure_pair("all_indices", function() cbind(
          wbt.Stull(weather$tas, weather$hurs), swbgt(weather$tas, weather$hurs),
          apparentTemp(weather$tas, weather$hurs, weather$wind),
          effectiveTemp(weather$tas, weather$hurs, weather$wind),
          humidex(weather$tas, weather$hurs), discomInd(weather$tas, weather$hurs),
          hi(weather$tas, weather$hurs)),
        function() heat_indices(weather$tas, weather$hurs, wind = weather$wind), n, climate)
    )
  }), recursive = FALSE)
}), recursive = FALSE)

result <- do.call(rbind, results)
print(result, row.names = FALSE)
output <- Sys.getenv("BENCHMARK_OUTPUT", unset = "")
if (nzchar(output)) utils::write.csv(result, output, row.names = FALSE)
