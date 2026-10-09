#' Liljegren outdoor wet-bulb globe temperature
#'
#' @inheritParams heat-stress-indices
#' @param dewp Dew point in degrees Celsius, using the inherited Dosseger
#'   humidity conversion documented in [heat_methods()].
#' @param wind Wind speed in m/s at 2 m. Height adjustment is a caller responsibility.
#' @param radiation Downwelling shortwave radiation in W/m2.
#' @param time POSIXct/POSIXlt instants or offset-bearing ISO 8601 strings.
#'   Observations are instantaneous; align interval data externally. Strings
#'   without an offset and date-only values are not accepted as instants.
#' @param lon,lat Longitude and latitude in degrees east and north.
#' @param direct_fraction Direct / (direct + diffuse) shortwave fraction, from
#'   zero through one. Default 0.8; scalar or row-aligned.
#' @param dewpoint_policy Cap dew point at air temperature (default), return NA
#'   for supersaturated rows ("na"), or stop the call ("error").
#' @param workers Number of temporary PSOCK processes; default 1. Respect the
#'   detected CPU count and R check core limits. Avoid nested worker pools.
#' @param control Named list of advanced controls: root_tolerance (1e-6 K),
#'   residual_tolerance (1e-4 K, at most 0.01), surface_albedo (0.45),
#'   globe_diameter (0.0508 m), and min_wind_speed (0.13 m/s).
#' @return An aligned numeric WBGT vector in degrees Celsius. With diagnostics,
#'   a list of values, components (tnwb and tg in C), and diagnostics. Detailed
#'   solver records retain initial/final brackets, residuals and fallback reasons.
#'   Bracket temperatures are Kelvin; candidate roots are Celsius. Final
#'   residuals and root/residual tolerances are Kelvin. Globe endpoint residuals
#'   use the energy equation (K to the fourth power); wet-bulb endpoints use K.
#' @details Uses the existing vectorized R heat-balance model with scalar
#'   fallback. A validated component is retained if its partner fails. Radiation
#'   is zeroed below the solar horizon and this adjustment is recorded in solver
#'   diagnostics. This independently maintained R model is not a bitwise port
#'   of the original Liljegren C program. Match physical assumptions before
#'   comparing implementations.
#' @author Original R translation: Ana Casanueva. Fork: Yifei Zheng.
#' @references Liljegren et al. (2008), doi:10.1080/15459620802310770.
#' @export
#' @examples
#' wbgt_liljegren(30, 22, 1.5, 700,
#'   as.POSIXct("2024-06-01 12:00:00", tz = "UTC"), 0, 15)
wbgt_liljegren <- function(tas, dewp, wind, radiation, time, lon, lat,
                           pressure = 1010, direct_fraction = 0.8,
                           dewpoint_policy = c("cap", "na", "error"),
                           diagnostics = FALSE, workers = 1L, control = list()) {
  options <- list(control = .liljegren_controls(control), workers = validate_workers(workers),
    engine = "batch", diagnostics = diagnostics, dewpoint_policy = match.arg(dewpoint_policy))
  .evaluate_method("wbgt_liljegren", list(tas = tas, dewp = dewp, wind_2m = wind,
    radiation = radiation, time = time, lon = lon, lat = lat, pressure = pressure,
    direct_fraction = direct_fraction), diagnostics, options)
}

#' Bernard indoor or shade wet-bulb globe temperature
#'
#' @inheritParams wbgt_liljegren
#' @param tolerance Maximum final psychrometric root bracket width in C.
#' @return Numeric WBGT in C, or the standardized diagnostic result with
#'   psychrometric wet-bulb component tpwb. Uses the inherited pressure assumption
#'   of 1010 hPa in Bernard's equation; it is not pressure configurable.
#' @author Original implementation: Ana Casanueva, P. Noti, J. Bhend.
#' @references Lemke and Kjellstrom (2012), doi:10.2486/indhealth.MS1352.
#' @export
#' @examples
#' wbgt_bernard(30, 20, diagnostics = TRUE)
wbgt_bernard <- function(tas, dewp, dewpoint_policy = c("cap", "na", "error"),
                         diagnostics = FALSE, tolerance = 1e-4) {
  validate_tolerance(tolerance, "tolerance")
  .evaluate_method("wbgt_bernard", list(tas = tas, dewp = dewp), diagnostics,
    list(dewpoint_policy = match.arg(dewpoint_policy), tolerance = tolerance))
}
