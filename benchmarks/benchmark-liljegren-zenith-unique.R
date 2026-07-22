#!/usr/bin/env Rscript

# Isolated solar-geometry benchmark. `unique` uses one coordinate pair per
# row; `shared` uses one coordinate pair for all distinct UTC timestamps.

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
root <- normalizePath(if (length(script_arg)) {
  file.path(dirname(sub("^--file=", "", script_arg[1])), "..")
} else {
  getwd()
})
source(file.path(root, "benchmarks", "liljegren-benchmark-utils.R"))
pkgload::load_all(root, quiet = TRUE)

rows <- liljegren_parse_positive_integers("ZENITH_UNIQUE_ROWS", 129024L)
repetitions <- liljegren_parse_positive_integers("BENCH_REPS", 3L)
if (length(rows) != 1L) stop("ZENITH_UNIQUE_ROWS must be one positive integer")
if (length(repetitions) != 1L) stop("BENCH_REPS must be one positive integer")
coordinate_mode <- Sys.getenv("ZENITH_COORDINATE_MODE", unset = "unique")
if (!coordinate_mode %in% c("unique", "shared")) {
  stop("ZENITH_COORDINATE_MODE must be unique or shared")
}

index <- seq_len(rows)
dates <- as.POSIXct("2020-01-01 00:00:00", tz = "UTC") + (index - 1L) * 3600
coordinates <- if (coordinate_mode == "unique") {
  liljegren_unique_coordinates(rows)
} else {
  list(lon = rep(-5.66, rows), lat = rep(40.96, rows))
}
coordinate_pairs <- liljegren_coordinate_pairs(coordinates$lon, coordinates$lat)
triplets <- paste(as.numeric(dates), sprintf("%a", coordinates$lon),
  sprintf("%a", coordinates$lat), sep = "\r")
if (length(unique(triplets)) != rows) {
  stop("benchmark workload must contain one unique timestamp-longitude-latitude triplet per row")
}
if (coordinate_mode == "unique" && coordinate_pairs != rows) {
  stop("unique mode must contain one coordinate pair per row")
}
if (coordinate_mode == "shared" && coordinate_pairs != 1L) {
  stop("shared mode must contain one coordinate pair")
}

measurement <- liljegren_measure(function() {
  HeatStressR:::calculate_liljegren_zenith(
    dates, coordinates$lon, coordinates$lat, hour = TRUE,
    gmt_offset = NULL, averaging_period = 0
  )
}, repetitions)
if (length(measurement$value) != rows || any(!is.finite(measurement$value))) {
  stop("zenith calculation returned invalid output")
}

result <- data.frame(
  benchmark = paste(coordinate_mode, "timestamp_longitude_latitude", sep = "_"),
  rows = rows,
  repetitions = repetitions,
  coordinate_mode = coordinate_mode,
  coordinate_pairs = coordinate_pairs,
  rows_per_coordinate_pair = rows / coordinate_pairs,
  unique_triplets = length(unique(triplets)),
  timestamp_frequency = "hourly",
  median_seconds = measurement$seconds,
  triplets_per_second = rows / measurement$seconds,
  r_version = R.version.string,
  platform = R.version$platform,
  row.names = NULL
)
print(result, row.names = FALSE)

output <- Sys.getenv("BENCHMARK_OUTPUT", unset = "")
if (nzchar(output)) utils::write.csv(result, output, row.names = FALSE)
