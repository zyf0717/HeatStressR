#' Calculate zenith angle in degrees.
#' 
#' Calculate zenith angle in degrees.
#' 
#' @param dates vector of dates, `POSIXct`/`POSIXlt` instants, or ISO 8601
#' datetime strings. With `hour = TRUE`, offset-bearing ISO 8601 strings (for example,
#' `2024-03-20T20:00:00+08:00` or `2024-03-20T12:00:00Z`) are interpreted as
#' instants and normalized to UTC. If a date-only value is provided, the
#' default time is 12:00 UTC.
#' @param lon single numeric longitude for the location, in degrees.
#' @param lat single numeric latitude for the location, in degrees.
#' @param hour logical. If TRUE, calculate from the full UTC timestamp. Default:
#'  FALSE (12:00 UTC is used for date-only inputs).
#' @param gmt_offset optional local-standard-time offset from GMT, in hours
#' (`LST - GMT`). When supplied, timestamps are interpreted as local standard
#' time rather than timezone-aware instants.
#' @param averaging_period averaging interval in minutes. Solar position is
#' evaluated at the interval midpoint, matching the original C implementation.
#' 
#' @return Numeric vector of zenith angles in degrees, aligned with `dates`.
#' @details `lon` and `lat` must be finite scalar values within their standard
#' ranges. Solar time incorporates longitude and the equation of time. Missing
#' dates return `NA` in the corresponding output position. Do not combine
#' `gmt_offset` with an offset-bearing ISO 8601 string: the latter already
#' identifies an instant.
#' @author Anke Duguay-Tetzlaff, Translated to R by Ana Casanueva (17.01.2017)
#' @export
#' 
#' @examples \dontrun{ 
#' calZenith("1981-06-15",  -5.66, 40.96)
#' calZenith("1981-06-15 10:00:00",  -5.66, 40.96, hour=TRUE)
#' calZenith("1981-06-15T18:00:00+08:00", -5.66, 40.96, hour=TRUE)
#' }
#' 
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

calculate_solar_time_terms <- function(dates, hour, gmt_offset,
                                       averaging_period) {
  DECL1 <- 0.006918
  DECL2 <- 0.399912
  DECL3 <- 0.070257
  DECL4 <- 0.006758
  DECL5 <- 0.000907
  DECL6 <- 0.002697
  DECL7 <- 0.00148

  # Without `gmt_offset`, POSIX timestamps and ISO 8601 strings with offsets
  # are timezone-aware instants normalized to UTC. With it, displayed clock
  # fields are local standard time, matching C.
  if (hour) {
    if (is.null(gmt_offset)) {
      if (inherits(dates, "POSIXt")) {
        timestamp <- as.POSIXct(dates, tz = "UTC")
      } else {
        d0 <- as.character(dates)
        timestamp <- parse_wall_datetime(d0)
        offset_timestamp <- parse_iso8601_datetime(d0)
        timestamp[!is.na(offset_timestamp)] <- offset_timestamp[!is.na(offset_timestamp)]
      }
    } else if (inherits(dates, "POSIXt")) {
      display_tz <- attr(dates, "tzone")
      if (!length(display_tz) || is.na(display_tz[1]) || !nzchar(display_tz[1])) display_tz <- ""
      d0 <- format(dates, format = "%Y-%m-%d %H:%M:%S", tz = display_tz[1])
      timestamp <- parse_wall_datetime(d0)
    } else {
      d0 <- as.character(dates)
      has_offset <- grepl("(?:Z|[+-]\\d{2}:?\\d{2})$", d0)
      if (any(has_offset, na.rm = TRUE)) {
        stop("'gmt_offset' must not be combined with offset-bearing ISO 8601 dates")
      }
      timestamp <- parse_wall_datetime(d0)
    }
  } else {
    d0 <- if (inherits(dates, "POSIXt")) format(dates, format = "%Y-%m-%d", tz = "UTC") else as.character(dates)
    timestamp <- as.POSIXct(strptime(d0, format = "%Y-%m-%d", tz = "UTC")) + 12 * 3600
  }
  if (!is.null(gmt_offset)) timestamp <- timestamp - gmt_offset * 3600
  timestamp <- timestamp - averaging_period * 30
  d1 <- as.POSIXlt(timestamp, tz = "UTC")
  utc_minutes <- as.numeric(format(d1, "%H")) * 60 +
    as.numeric(format(d1, "%M")) + as.numeric(format(d1, "%S")) / 60
  year <- as.numeric(format(d1, "%Y"))
  doy <- as.numeric(strftime(d1, format = "%j"))
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

calZenith <- function(dates, lon, lat, hour = FALSE, gmt_offset = NULL,
                      averaging_period = 0) {
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
  assertthat::assert_that(is.null(gmt_offset) ||
    (is.numeric(gmt_offset) && length(gmt_offset) == 1L && is.finite(gmt_offset)),
    msg = "'gmt_offset' must be NULL or one finite number")
  assertthat::assert_that(is.numeric(averaging_period) && length(averaging_period) == 1L &&
    is.finite(averaging_period) && averaging_period >= 0,
    msg = "'averaging_period' must be one non-negative finite number")

  if (!length(dates)) return(numeric(0))
  terms <- calculate_solar_time_terms(dates, hour, gmt_offset, averaging_period)
  calculate_zenith_from_solar_terms(
    terms$utc_minutes, terms$equation_of_time, terms$declination, lon, lat
  )
}
