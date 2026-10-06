#' Meteorological heat-stress indices
#'
#' Calculate one index from aligned observations. Numeric scalars expand to the
#' common observation length; other unequal lengths and matrices are rejected.
#' Missing inputs propagate silently. Invalid observations return NA with one
#' summary warning. Outside documented applicability bounds, a formula is
#' evaluated where possible and flagged with a warning. Unknown bounds do not
#' establish validity.
#'
#' @param tas Air temperature in degrees Celsius.
#' @param hurs Relative humidity in percent. The method catalog documents phase
#'   conventions. Methods using inherited Dosseger vapour pressure switch
#'   reference phase at 0 C; formulas using RH directly perform no conversion. Romps/Lu
#'   follow heatindex's water/ice convention at 273.16 K. Supply humidity on the
#'   chosen method's stated reference phase, especially below freezing.
#' @param wind Wind speed in m/s measured at 10 m. Height adjustment is not
#'   performed for apparent or effective temperature.
#' @param pressure Atmospheric pressure in hPa, default 1010. This is an explicit
#'   near-sea-level assumption; use observed pressure at elevation.
#' @param diagnostics Return values, component temperatures and diagnostics.
#' @return By default, an aligned numeric vector on the Celsius scale. Humidex
#'   uses a Celsius-equivalent index scale. With diagnostics=TRUE, a list with
#'   values, components, and diagnostics. diagnostics contains a rows data frame
#'   (input_status, input_reason, domain_status, adjusted, converged,
#'   failure_reason), optional method-specific solver detail, and metadata.
#' @details Romps calculates thermodynamic liquid-water wet bulb, not natural
#'   or aspirated wet bulb. Lu uses the simplified model published in 2026.
#'   Both call the external heatindex package; numerical reproducibility requires
#'   pinning its version. Stull assumes sea-level pressure and has a restricted
#'   domain. Cold observations within its rectangular bounds are marked unknown
#'   because its excluded cold/dry corner has no numeric boundary in the paper.
#'
#'   Simplified WBGT uses vapour pressure e in hPa from the shared Dosseger
#'   kernel. ABM: 0.567*tas + 0.393*e + 3.94; indoor: 0.567*tas + 0.216*e + 3.38.
#'   These empirical approximations do not calculate radiation or wind effects.
#' @references
#' * Stull (2011), \doi{10.1175/JAMC-D-11-0143.1}.
#' * Romps (2026), \doi{10.1175/JAMC-D-25-0130.1}.
#' * Lu et al. (2026), \doi{10.1175/JAMC-D-25-0067.1}.
#' * Lemke and Kjellstrom (2012), \doi{10.2486/indhealth.MS1352}.
#' * [NWS Heat Index procedure](https://www.wpc.ncep.noaa.gov/html/heatindex_equation.shtml).
#' @seealso [heat_methods()], [heat_indices()], [wbgt_liljegren()]
#' @name heat-stress-indices
#' @examples
#' heat_index_rothfusz(c(25, 35), c(50, 10))
#' wet_bulb_romps(30, 70, pressure = 950)
#' wet_bulb_stull(c(30, 55), 50, diagnostics = TRUE)
NULL

#' @rdname heat-stress-indices
#' @export
wet_bulb_stull <- function(tas, hurs, diagnostics = FALSE) {
  .evaluate_method("wet_bulb_stull", list(tas = tas, hurs = hurs), diagnostics)
}

#' @rdname heat-stress-indices
#' @export
wet_bulb_romps <- function(tas, hurs, pressure = 1010, diagnostics = FALSE) {
  .evaluate_method("wet_bulb_romps", list(tas = tas, hurs = hurs, pressure = pressure), diagnostics)
}

#' @rdname heat-stress-indices
#' @export
heat_index_rothfusz <- function(tas, hurs, diagnostics = FALSE) {
  .evaluate_method("heat_index_rothfusz", list(tas = tas, hurs = hurs), diagnostics)
}

#' @rdname heat-stress-indices
#' @export
heat_index_lu <- function(tas, hurs, diagnostics = FALSE) {
  .evaluate_method("heat_index_lu", list(tas = tas, hurs = hurs), diagnostics)
}

#' @rdname heat-stress-indices
#' @export
wbgt_simplified_abm <- function(tas, hurs, diagnostics = FALSE) {
  .evaluate_method("wbgt_simplified_abm", list(tas = tas, hurs = hurs), diagnostics)
}

#' @rdname heat-stress-indices
#' @export
wbgt_simplified_indoor <- function(tas, hurs, diagnostics = FALSE) {
  .evaluate_method("wbgt_simplified_indoor", list(tas = tas, hurs = hurs), diagnostics)
}

#' @rdname heat-stress-indices
#' @export
apparent_temperature <- function(tas, hurs, wind, diagnostics = FALSE) {
  .evaluate_method("apparent_temperature", list(tas = tas, hurs = hurs, wind_10m = wind), diagnostics)
}

#' @rdname heat-stress-indices
#' @export
effective_temperature <- function(tas, hurs, wind, diagnostics = FALSE) {
  .evaluate_method("effective_temperature", list(tas = tas, hurs = hurs, wind_10m = wind), diagnostics)
}

#' @rdname heat-stress-indices
#' @export
humidex <- function(tas, hurs, diagnostics = FALSE) {
  .evaluate_method("humidex", list(tas = tas, hurs = hurs), diagnostics)
}

#' @rdname heat-stress-indices
#' @export
discomfort_index <- function(tas, hurs, diagnostics = FALSE) {
  .evaluate_method("discomfort_index", list(tas = tas, hurs = hurs), diagnostics)
}
