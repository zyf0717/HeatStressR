# Shared deterministic workloads for Liljegren benchmarks.

liljegren_benchmark_root <- function() {
  script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  candidate <- if (length(script_arg)) {
    file.path(dirname(sub("^--file=", "", script_arg[1])), "..")
  } else {
    getwd()
  }
  normalizePath(candidate)
}

liljegren_parse_positive_integers <- function(variable, defaults) {
  value <- Sys.getenv(variable, unset = "")
  if (!nzchar(value)) return(as.integer(defaults))
  parsed <- suppressWarnings(as.numeric(strsplit(value, ",", fixed = TRUE)[[1]]))
  if (any(is.na(parsed) | !is.finite(parsed) | parsed < 1 | parsed != floor(parsed)))
    stop(variable, " must contain positive integers")
  as.integer(parsed)
}

liljegren_coordinate_modes <- function(variable = "LILJEGREN_COORDINATE_MODES",
                                        defaults = c("fixed", "grouped", "unique")) {
  value <- Sys.getenv(variable, unset = "")
  modes <- if (nzchar(value)) strsplit(value, ",", fixed = TRUE)[[1]] else defaults
  modes <- unique(trimws(modes))
  if (!length(modes) || any(!modes %in% c("fixed", "grouped", "unique"))) {
    stop(variable, " must contain fixed, grouped, and/or unique")
  }
  modes
}

liljegren_dataset_path <- function(root = liljegren_benchmark_root()) {
  Sys.getenv("LILJEGREN_BENCHMARK_DATASET", unset = file.path(root,
    "benchmarks", "data", "liljegren-multi-location-e2e.csv"))
}

liljegren_read_dataset <- function(n, path = liljegren_dataset_path()) {
  required <- c("date", "lon", "lat", "tas", "dewp", "wind", "radiation")
  if (!file.exists(path)) stop("Liljegren benchmark dataset does not exist: ", path)
  data <- utils::read.csv(path, stringsAsFactors = FALSE)
  if (!all(required %in% names(data))) {
    stop("Liljegren benchmark dataset must contain: ", paste(required, collapse = ", "))
  }
  if (!nrow(data)) stop("Liljegren benchmark dataset must contain at least one row")
  numeric_columns <- setdiff(required, "date")
  if (any(!vapply(data[numeric_columns], is.numeric, logical(1))) ||
      any(!is.finite(as.matrix(data[numeric_columns])))) {
    stop("Liljegren benchmark dataset numeric columns must be finite")
  }
  dates <- as.POSIXct(data$date, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  if (any(is.na(dates))) stop("Liljegren benchmark dates must be ISO 8601 UTC timestamps")
  # Interleave locations by timestamp so smoke-scale workloads exercise the
  # coordinate-grouping path rather than consuming one location at a time.
  order_index <- order(dates, data$lon, data$lat)
  data <- data[order_index, , drop = FALSE]
  dates <- dates[order_index]
  index <- rep(seq_len(nrow(data)), length.out = n)
  list(
    tas = data$tas[index], dewp = data$dewp[index], wind = data$wind[index],
    radiation = data$radiation[index], dates = dates[index], lon = data$lon[index],
    lat = data$lat[index]
  )
}

liljegren_unique_coordinates <- function(n) {
  index <- seq_len(n)
  list(
    lon = ((index * 137.50776405003785) %% 360) - 180,
    lat = 80 * sin(index * 0.6180339887498949)
  )
}

liljegren_benchmark_zenith <- function(dates, lon, lat) {
  coordinate_id <- paste(sprintf("%a", lon), sprintf("%a", lat), sep = "\r")
  groups <- split(seq_along(dates), match(coordinate_id, unique(coordinate_id)))
  zenith <- rep(NA_real_, length(dates))
  for (index in groups) {
    zenith[index] <- HeatStressR:::degToRad(calZenith(
      dates[index], lon[index[1L]], lat[index[1L]], hour = TRUE
    ))
  }
  zenith
}

liljegren_rebuild_radiation <- function(weather) {
  zenith <- liljegren_benchmark_zenith(weather$dates, weather$lon, weather$lat)
  weather$radiation <- 900 * pmax(cos(zenith), 0)
  weather
}

liljegren_coordinate_pairs <- function(lon, lat) {
  length(unique(paste(sprintf("%a", lon), sprintf("%a", lat), sep = "\r")))
}

liljegren_workload <- function(n, mode = "grouped",
                                path = liljegren_dataset_path()) {
  weather <- liljegren_read_dataset(n, path)
  if (mode == "fixed") {
    weather$lon[] <- weather$lon[1L]
    weather$lat[] <- weather$lat[1L]
    weather <- liljegren_rebuild_radiation(weather)
  } else if (mode == "unique") {
    coordinates <- liljegren_unique_coordinates(n)
    weather$lon <- coordinates$lon
    weather$lat <- coordinates$lat
    weather <- liljegren_rebuild_radiation(weather)
  } else if (mode != "grouped") {
    stop("mode must be fixed, grouped, or unique")
  }
  attr(weather, "coordinate_mode") <- mode
  attr(weather, "coordinate_pairs") <- liljegren_coordinate_pairs(weather$lon, weather$lat)
  weather
}

liljegren_workload_metadata <- function(weather) {
  n <- length(weather$tas)
  pairs <- attr(weather, "coordinate_pairs")
  data.frame(
    coordinate_mode = attr(weather, "coordinate_mode"),
    coordinate_pairs = pairs,
    rows_per_coordinate_pair = n / pairs,
    row.names = NULL
  )
}

liljegren_measure <- function(work, repetitions) {
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

liljegren_maximum_difference <- function(reference, candidate) {
  valid <- !is.na(reference) & !is.na(candidate)
  if (!any(valid)) return(0)
  max(abs(reference[valid] - candidate[valid]))
}

liljegren_compare_results <- function(reference, candidate) {
  components <- c("data", "Tg", "Tnwb")
  differences <- vapply(components, function(component) {
    liljegren_maximum_difference(reference[[component]], candidate[[component]])
  }, numeric(1))
  list(
    na_aligned = all(vapply(components, function(component) identical(
      is.na(reference[[component]]), is.na(candidate[[component]])
    ), logical(1))),
    max_data_difference = differences[["data"]],
    max_Tg_difference = differences[["Tg"]],
    max_Tnwb_difference = differences[["Tnwb"]]
  )
}

liljegren_maximum_residual <- function(diagnostics) {
  values <- c(diagnostics$Tg$final_residual, diagnostics$Tnwb$final_residual)
  values <- values[is.finite(values)]
  if (!length(values)) return(NA_real_)
  max(abs(values))
}
