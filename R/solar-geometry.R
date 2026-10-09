parse_wall_datetime <- function(x) {
  result <- rep(NA_real_, length(x))
  x <- sub("T", " ", x, fixed = TRUE)
  # DEPRECATED(v4): date-only parsing is used by .legacy_times(); keep datetime parsing.
  has_date <- grepl("^\\d{4}-\\d{2}-\\d{2}$", x)
  has_seconds <- grepl("^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}(?:\\.\\d+)?$", x)
  has_minutes <- grepl("^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}$", x)

  if (any(has_date)) {
    result[has_date] <- as.numeric(as.POSIXct(strptime(
      x[has_date], format = "%Y-%m-%d", tz = "UTC"
    )))
  }
  if (any(has_seconds)) {
    parsed <- as.POSIXct(strptime(x[has_seconds], format = "%Y-%m-%d %H:%M:%OS", tz = "UTC"))
    result[has_seconds] <- as.numeric(parsed)
  }
  if (any(has_minutes)) {
    result[has_minutes] <- as.numeric(as.POSIXct(strptime(
      x[has_minutes], format = "%Y-%m-%d %H:%M", tz = "UTC"
    )))
  }
  as.POSIXct(result, origin = "1970-01-01", tz = "UTC")
}

parse_iso8601_datetime <- function(x) {
  has_offset <- grepl(
    "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}(?::\\d{2}(?:\\.\\d+)?)?(?:Z|[+-]\\d{2}:?\\d{2})$",
    x
  )
  result <- rep(as.POSIXct(NA, tz = "UTC"), length(x))
  if (!any(has_offset)) return(result)

  timezone <- sub("^.*(Z|[+-]\\d{2}:?\\d{2})$", "\\1", x[has_offset])
  wall_time <- sub("(Z|[+-]\\d{2}:?\\d{2})$", "", x[has_offset])
  parsed <- parse_wall_datetime(wall_time)
  offset_seconds <- numeric(length(timezone))
  numeric_offset <- timezone != "Z"
  offset_hours <- as.numeric(substr(timezone[numeric_offset], 2, 3))
  offset_minutes <- as.numeric(substr(timezone[numeric_offset],
    nchar(timezone[numeric_offset]) - 1, nchar(timezone[numeric_offset])))
  offset_seconds[numeric_offset] <- (offset_hours * 3600 + offset_minutes * 60) *
    ifelse(substr(timezone[numeric_offset], 1, 1) == "-", -1, 1)
  invalid_offset <- rep(FALSE, length(timezone))
  invalid_offset[numeric_offset] <- offset_hours > 23 | offset_minutes > 59
  parsed[which(invalid_offset)] <- NA
  result[has_offset] <- parsed - offset_seconds
  result
}

.solar_time_terms <- function(dates) {
  DECL1 <- 0.006918
  DECL2 <- 0.399912
  DECL3 <- 0.070257
  DECL4 <- 0.006758
  DECL5 <- 0.000907
  DECL6 <- 0.002697
  DECL7 <- 0.00148

  timestamp <- as.POSIXct(dates, tz = "UTC")
  d1 <- as.POSIXlt(timestamp, tz = "UTC")
  utc_minutes <- d1$hour * 60 + d1$min + d1$sec / 60
  year <- d1$year + 1900
  doy <- d1$yday + 1
  # Gregorian leap-year rule, adapted from Sven Kotlarski's original helper.
  leap_year <- year %% 4 == 0 & (year %% 100 != 0 | year %% 400 == 0)
  dpy <- ifelse(leap_year, 366, 365)
  utc_hour <- utc_minutes / 60
  gamma <- 2 * pi * ((doy - 1) + ((utc_hour - 12) / 24)) / dpy
  equation_of_time <- 229.18 * (0.000075 + 0.001868 * cos(gamma) -
    0.032077 * sin(gamma) - 0.014615 * cos(2 * gamma) -
    0.040849 * sin(2 * gamma))
  declination <- DECL1 - DECL2 * cos(gamma) + DECL3 * sin(gamma) -
    DECL4 * cos(2 * gamma) + DECL5 * sin(2 * gamma) -
    DECL6 * cos(3 * gamma) + DECL7 * sin(3 * gamma)

  list(
    utc_minutes = utc_minutes,
    equation_of_time = equation_of_time,
    declination = declination
  )
}

calculate_zenith_from_solar_terms <- function(utc_minutes, equation_of_time,
                                              declination, lon, lat) {
  rad_lat <- degToRad(lat)
  true_solar_time <- (utc_minutes + equation_of_time + 4 * lon) %% 1440
  hour_angle_rad <- degToRad((true_solar_time / 4) - 180)
  cos_zenith <- sin(rad_lat) * sin(declination) +
    cos(rad_lat) * cos(declination) * cos(hour_angle_rad)
  cos_zenith <- pmin(1, pmax(-1, cos_zenith))

  radToDeg(acos(cos_zenith))
}
