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

root <- benchmark_root()
pkgload::load_all(root, quiet = TRUE)

parse_positive_integer <- function(name, default) {
  value <- as.integer(Sys.getenv(name, unset = as.character(default)))
  if (length(value) != 1L || is.na(value) || value < 1L) {
    stop(name, " must be a positive integer")
  }
  value
}

parse_latitudes <- function(value) {
  latitudes <- suppressWarnings(as.numeric(strsplit(value, ",", fixed = TRUE)[[1]]))
  if (!length(latitudes) || any(!is.finite(latitudes) | latitudes < -90 | latitudes > 90)) {
    stop("MULTI_LOCATION_LATITUDES must be finite values from -90 through 90")
  }
  latitudes
}

longitude_count <- parse_positive_integer("MULTI_LOCATION_LON_COUNT", 12L)
latitude_values <- parse_latitudes(Sys.getenv("MULTI_LOCATION_LATITUDES",
  unset = "-60,-20,20,60"))
days <- parse_positive_integer("MULTI_LOCATION_DAYS", 2L)
seed <- parse_positive_integer("MULTI_LOCATION_SEED", 20260722L)
set.seed(seed)

coordinates <- expand.grid(
  lon = seq(-180 + 180 / longitude_count, 180 - 180 / longitude_count,
    length.out = longitude_count),
  lat = latitude_values,
  KEEP.OUT.ATTRS = FALSE
)
coordinates$location_id <- sprintf("grid_%02d", seq_len(nrow(coordinates)))
times <- as.POSIXct("2024-03-01 00:00:00", tz = "UTC") +
  seq_len(days * 24L) * 3600 - 3600

location <- rep(seq_len(nrow(coordinates)), each = length(times))
dates <- rep(times, times = nrow(coordinates))
lon <- coordinates$lon[location]
lat <- coordinates$lat[location]
zenith <- unlist(lapply(seq_len(nrow(coordinates)), function(i) {
  HeatStressR:::degToRad(calZenith(times, coordinates$lon[i], coordinates$lat[i],
    hour = TRUE))
}), use.names = FALSE)
hour <- as.numeric(format(dates, "%H", tz = "UTC"))
phase <- 2 * pi * (hour - 14) / 24
location_temperature <- 27 - abs(coordinates$lat) * 0.09 +
  stats::runif(nrow(coordinates), -3, 3)
diurnal_range <- stats::runif(nrow(coordinates), 4, 8)
dewpoint_depression <- stats::runif(nrow(coordinates), 1.5, 8)
temperature <- pmin(42, pmax(-10, location_temperature[location] +
  diurnal_range[location] * cos(phase) + stats::rnorm(length(location), 0, 0.5)))
dewpoint <- temperature - pmin(12, pmax(0.5, dewpoint_depression[location] +
  stats::rnorm(length(location), 0, 0.4)))
wind <- stats::runif(length(location), 0.2, 6.5)
radiation <- 950 * pmax(cos(zenith), 0) * stats::runif(length(location), 0.35, 1)

dataset <- data.frame(
  location_id = coordinates$location_id[location],
  date = format(dates, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  lon = lon,
  lat = lat,
  tas = round(temperature, 3),
  dewp = round(dewpoint, 3),
  wind = round(wind, 3),
  radiation = round(radiation, 3),
  stringsAsFactors = FALSE
)

output <- Sys.getenv("MULTI_LOCATION_DATASET", unset =
  file.path(root, "benchmarks", "data", "liljegren-multi-location-e2e.csv"))
dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(dataset, output, row.names = FALSE)
message("Wrote ", nrow(dataset), " rows across ", nrow(coordinates),
  " coordinate pairs (", days, " days, seed ", seed, ") to ",
  normalizePath(output))
