#' Meteorological humidity conversions
#'
#' @inheritParams heat-stress-indices
#' @param dewp Dew point in degrees Celsius.
#' @param dewpoint_policy Handling of dew point above air temperature: cap,
#'   na, or error. Default cap.
#' @return An aligned numeric vector: vapour pressure in hPa or RH in percent.
#' @details Uses the paired inherited Dosseger equations. Coefficients are
#'   selected by air temperature: water at or above 0 C, ice below 0 C. This
#'   preserves that convention when dew point and air temperature straddle 0 C.
#' @name humidity-conversions
#' @examples
#' vapour_pressure(30, 70)
#' relative_humidity(30, 20)
NULL

#' @rdname humidity-conversions
#' @export
vapour_pressure <- function(tas, hurs) {
  p <- .prepare_inputs(list(tas = tas, hurs = hurs))
  values <- as.numeric(.vapour_pressure_hpa(p$inputs$tas, p$inputs$hurs))
  failed <- p$valid & !is.finite(values)
  values[!is.finite(values)] <- NA_real_
  .warn_method_rows("vapour_pressure", p$status, rep("unknown", p$n), rep(FALSE, p$n), failed)
  values
}

#' @rdname humidity-conversions
#' @export
relative_humidity <- function(tas, dewp, dewpoint_policy = c("cap", "na", "error")) {
  p <- .apply_dewpoint_policy(.prepare_inputs(list(tas = tas, dewp = dewp)), match.arg(dewpoint_policy))
  values <- as.numeric(.relative_humidity_percent(p$inputs$tas, p$inputs$dewp))
  failed <- p$valid & !is.finite(values)
  values[!is.finite(values)] <- NA_real_
  .warn_method_rows("relative_humidity", p$status, rep("unknown", p$n), p$adjusted, failed)
  values
}

#' Solar zenith angle at supplied instants
#'
#' @inheritParams wbgt_liljegren
#' @return Numeric solar zenith angles in degrees, aligned with time.
#' @export
#' @examples
#' solar_zenith("2024-06-01T12:00:00Z", 0, 15)
solar_zenith <- function(time, lon, lat) {
  p <- .prepare_inputs(list(time = time, lon = lon, lat = lat))
  .warn_method_rows("solar_zenith", p$status, rep("unknown", p$n), rep(FALSE, p$n), rep(FALSE, p$n))
  radToDeg(.liljegren_zenith(p$inputs$time, p$inputs$lon, p$inputs$lat))
}
