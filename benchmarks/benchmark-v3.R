# Reproducible canonical workload timings; no files are written unless requested.
pkgload::load_all(Sys.getenv("BENCHMARK_ROOT", unset = getwd()), quiet = TRUE)
sizes <- as.integer(strsplit(Sys.getenv("V3_ROWS", unset = "10000,100000"), ",", fixed = TRUE)[[1]])
repetitions <- as.integer(Sys.getenv("BENCH_REPS", unset = "3"))
stopifnot(all(is.finite(sizes) & sizes > 0), length(repetitions) == 1, is.finite(repetitions), repetitions > 0)
measure <- function(f) {
  timings <- replicate(repetitions, {
    gc()
    started <- proc.time()[["elapsed"]]
    value <- f()
    stopifnot(length(value) > 0)
    proc.time()[["elapsed"]] - started
  })
  median(timings)
}
rows <- list()
for (n in sizes) {
  i <- seq_len(n)
  tas <- 28 + 5 * sin(i / 24)
  hurs <- rep(c(40, 60, 80), length.out = n)
  time <- as.POSIXct("2020-01-01", tz = "UTC") + (i - 1) * 3600
  radiation <- 750 * pmax(cos(HeatStressR:::degToRad(solar_zenith(time, 0, 15))), 0)
  calculations <- list(
    romps = function() wet_bulb_romps(tas, hurs),
    lu = function() heat_index_lu(tas, hurs),
    bulk_explicit = function() heat_indices(tas, hurs, indices = c("humidex", "heat_index_lu", "wet_bulb_romps")),
    bulk_auto = function() heat_indices(tas, hurs),
    liljegren = function() wbgt_liljegren(tas, tas - 8, rep(1.5, n), radiation, time, 0, 15))
  for (name in names(calculations)) {
    rows[[length(rows) + 1L]] <- data.frame(method = name, rows = n,
      seconds = measure(calculations[[name]]), R = as.character(getRversion()),
      heatindex = as.character(packageVersion("heatindex")))
  }
}
result <- do.call(rbind, rows)
print(result, row.names = FALSE)
output <- Sys.getenv("BENCHMARK_OUTPUT", unset = "")
if (nzchar(output)) write.csv(result, output, row.names = FALSE)
