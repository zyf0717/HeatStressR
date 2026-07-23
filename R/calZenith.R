#' Calculate zenith angle in degrees.
#' 
#' Calculate zenith angle in degrees.
#' 
#' @param dates vector of dates, `POSIXct`/`POSIXlt` instants, or ISO 8601
#' datetime strings. With `solar_time = "timestamp"`, offset-bearing ISO 8601 strings (for example,
#' `2024-03-20T20:00:00+08:00` or `2024-03-20T12:00:00Z`) are interpreted as
#' instants and normalized to UTC. `solar_time = "date_noon"` evaluates each
#' date at 12:00 UTC.
#' @param lon single numeric longitude for the location, in degrees.
#' @param lat single numeric latitude for the location, in degrees.
#' @param hour legacy logical solar-time selector. Use `solar_time` in new code.
#' @param solar_time `"timestamp"` uses each full timestamp; `"date_noon"`
#' evaluates each date at 12:00 UTC. `NULL` preserves the legacy `hour` behavior.
#' 
#' @return Numeric vector of zenith angles in degrees, aligned with `dates`.
#' @details `lon` and `lat` must be finite scalar values within their standard
#' ranges. Solar time incorporates longitude and the equation of time. Missing
#' dates return `NA` in the corresponding output position.
#' @author Anke Duguay-Tetzlaff, Translated to R by Ana Casanueva (17.01.2017)
#' 
#' @examples \dontrun{ 
#' calZenith("1981-06-15",  -5.66, 40.96)
#' calZenith("1981-06-15 10:00:00",  -5.66, 40.96, solar_time = "timestamp")
#' calZenith("1981-06-15T18:00:00+08:00", -5.66, 40.96, solar_time = "timestamp")
#' }
#' @noRd
parse_wall_datetime <- function(x) {
  result <- rep(NA_real_, length(x))
  x <- sub("T", " ", x, fixed = TRUE)
  has_seconds <- grepl("^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}(?:\\.\\d+)?$", x)
  has_minutes <- grepl("^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}$", x)

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
  result[has_offset] <- parsed - offset_seconds
  result
}

resolve_solar_time <- function(hour, solar_time, hour_supplied) {
  if (is.null(solar_time)) return(hour)
  if (!is.character(solar_time) || length(solar_time) != 1L ||
      is.na(solar_time) || !solar_time %in% c("timestamp", "date_noon")) {
    stop("'solar_time' must be one of \"timestamp\" or \"date_noon\"")
  }
  timestamp <- identical(solar_time, "timestamp")
  if (hour_supplied && !identical(hour, timestamp)) {
    stop("'hour' and 'solar_time' specify conflicting solar-time modes")
  }
  timestamp
}

calculate_solar_time_terms <- function(dates, hour) {
  DECL1 <- 0.006918
  DECL2 <- 0.399912
  DECL3 <- 0.070257
  DECL4 <- 0.006758
  DECL5 <- 0.000907
  DECL6 <- 0.002697
  DECL7 <- 0.00148

  # POSIX timestamps and ISO 8601 strings with offsets are timezone-aware
  # instants normalized to UTC.
  if (hour) {
    if (inherits(dates, "POSIXt")) {
      timestamp <- as.POSIXct(dates, tz = "UTC")
    } else {
      d0 <- as.character(dates)
      timestamp <- parse_wall_datetime(d0)
      offset_timestamp <- parse_iso8601_datetime(d0)
      timestamp[!is.na(offset_timestamp)] <- offset_timestamp[!is.na(offset_timestamp)]
    }
  } else {
    d0 <- if (inherits(dates, "POSIXt")) format(dates, format = "%Y-%m-%d", tz = "UTC") else as.character(dates)
    timestamp <- as.POSIXct(strptime(d0, format = "%Y-%m-%d", tz = "UTC")) + 12 * 3600
  }
  d1 <- as.POSIXlt(timestamp, tz = "UTC")
  utc_minutes <- d1$hour * 60 + d1$min + d1$sec / 60
  year <- d1$year + 1900
  doy <- d1$yday + 1
  dpy <- ifelse(is.leapyear(year), 366, 365)
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

#' Calculate zenith angle in degrees.
#'
#' @param dates vector of dates, \code{POSIXct}/\code{POSIXlt} instants, or ISO 8601
#' datetime strings. Use timezone-aware \code{POSIXct} for high-throughput
#' calls. With \code{solar_time = "timestamp"}, offset-bearing ISO 8601 strings
#' are interpreted as instants and normalized to UTC; strings are parsed on
#' every call. \code{solar_time = "date_noon"} evaluates each date at 12:00 UTC.
#' @param lon single numeric longitude for the location, in degrees.
#' @param lat single numeric latitude for the location, in degrees.
#' @param hour legacy logical solar-time selector. Use \code{solar_time} in new code.
#' @param solar_time \code{"timestamp"} uses each full timestamp;
#' \code{"date_noon"} evaluates each date at 12:00 UTC. \code{NULL} preserves
#' the legacy \code{hour} behavior.
#'
#' @return Numeric vector of zenith angles in degrees, aligned with \code{dates}.
#' @details \code{lon} and \code{lat} must be finite scalar values within their standard
#' ranges. Solar time incorporates longitude and the equation of time. Missing
#' dates return \code{NA} in the corresponding output position.
#' @author Anke Duguay-Tetzlaff, Translated to R by Ana Casanueva (17.01.2017)
#' @export
#'
#' @examples \dontrun{
#' calZenith("1981-06-15", -5.66, 40.96)
#' calZenith("1981-06-15 10:00:00", -5.66, 40.96, solar_time = "timestamp")
#' calZenith("1981-06-15T18:00:00+08:00", -5.66, 40.96, solar_time = "timestamp")
#' }
calZenith <- function(dates, lon, lat, hour = FALSE, solar_time = NULL) {
  hour_supplied <- !missing(hour)
  hour <- resolve_solar_time(hour, solar_time, hour_supplied)
  assertthat::assert_that(
    is.logical(hour) && length(hour) == 1L && !is.na(hour),
    msg = "'hour' should be a single non-missing logical value"
  )
  assertthat::assert_that(
    is.numeric(lon) && length(lon) == 1L && is.finite(lon),
    msg = "'lon' should be a single finite numeric value"
  )
  assertthat::assert_that(
    is.numeric(lat) && length(lat) == 1L && is.finite(lat),
    msg = "'lat' should be a single finite numeric value"
  )
  assertthat::assert_that(lon <= 180 && lon >= -180, msg = "Invalid lon")
  assertthat::assert_that(lat <= 90 && lat >= -90, msg = "Invalid lat")
  if (!length(dates)) return(numeric(0))
  terms <- calculate_solar_time_terms(dates, hour)
  calculate_zenith_from_solar_terms(
    terms$utc_minutes, terms$equation_of_time, terms$declination, lon, lat
  )
}
