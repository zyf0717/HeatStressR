# DEPRECATED(v4): This entire file is the removable 2.x compatibility layer.
# Public replacements never call these endpoints. See inst/DEPRECATIONS.md.

.legacy_endpoints <- c(apparentTemp = "apparent_temperature",
  effectiveTemp = "effective_temperature", discomInd = "discomfort_index",
  hi = "heat_index_rothfusz", swbgt = "wbgt_simplified_indoor",
  wbt.Stull = "wet_bulb_stull", wbgt.Bernard = "wbgt_bernard",
  wbgt.Liljegren = "wbgt_liljegren", dewp2hurs = "relative_humidity",
  tashurs2vap.pres = "vapour_pressure", indexShow = "heat_methods",
  calZenith = "solar_zenith", fTg = "wbgt_liljegren",
  fTnwb = "wbgt_liljegren")

.legacy_times <- function(dates, hour) {
  if (hour) {
    if (inherits(dates, "POSIXt")) return(.normalise_time(dates))
    d <- as.character(dates)
    result <- parse_wall_datetime(d)
    offset <- parse_iso8601_datetime(d)
    result[!is.na(offset)] <- offset[!is.na(offset)]
    result
  } else {
    d <- if (inherits(dates, "POSIXt")) format(.normalise_time(dates), "%Y-%m-%d", tz = "UTC") else as.character(dates)
    as.POSIXct(strptime(d, "%Y-%m-%d", tz = "UTC")) + 12 * 3600
  }
}

resolve_solar_time <- function(hour, solar_time, hour_supplied, solar_time_supplied) {
  .logical_control(hour, "hour")
  if (!solar_time_supplied) return(if (hour_supplied) hour else TRUE)
  .assert(is.character(solar_time) && length(solar_time) == 1L &&
    !is.na(solar_time) && solar_time %in% c("timestamp", "date_noon"),
    "'solar_time' must be one of \"timestamp\" or \"date_noon\"")
  timestamp <- identical(solar_time, "timestamp")
  if (hour_supplied && !identical(hour, timestamp)) stop("'hour' and 'solar_time' specify conflicting solar-time modes", call. = FALSE)
  timestamp
}

# Kept only for old internal/reference callers; the core uses .liljegren_zenith.
calculate_liljegren_zenith <- function(dates, lon, lat, hour) {
  .liljegren_zenith(.legacy_times(dates, hour), lon, lat)
}

.legacy_swap <- function(tas, dewp, noNAs, swap) {
  .logical_control(noNAs, "noNAs")
  .logical_control(swap, "swap")
  adjusted <- noNAs & swap & !is.na(tas) & !is.na(dewp) & dewp > tas
  if (noNAs && swap) {
    old_tas <- tas
    tas <- pmax(tas, dewp)
    dewp <- pmin(old_tas, dewp)
  }
  list(tas = tas, dewp = dewp, adjusted = adjusted,
    policy = if (noNAs) "cap" else "na")
}

# Only heat_indices' marked compatibility hook calls this helper.
.legacy_bulk_wind <- function(wind, wind_10m) {
  if (is.null(wind)) return(wind_10m)
  .warn_deprecation("heat_indices(wind)", "heat_indices(wind_10m)")
  if (!is.null(wind_10m) && !identical(wind, wind_10m))
    stop("'wind' and 'wind_10m' conflict", call. = FALSE)
  wind
}

#' Deprecated HeatStressR 2.x endpoints
#'
#' Compatibility adapters preserve names, positional arguments and return
#' shapes. Scientific corrections and invalid-row handling follow the canonical
#' APIs. Each endpoint warns once per session and will be removed no earlier
#' than v4.0.0. New code should use the replacements in [heat_methods()].
#'
#' @param tas,dewp,hurs Air/dew-point temperature in C and RH in percent.
#' @param wind Wind in m/s: 10 m for apparent/effective temperature, 2 m for WBGT.
#' @param dates Legacy timestamps or date strings. Unzoned strings use UTC.
#' @param lon,lat Coordinates in degrees east/north.
#' @param radiation Solar shortwave radiation in W/m2.
#' @param tolerance Legacy tolerance mapped to numerical controls.
#' @param noNAs,swap Legacy dew-point cap/reject/swap selection. Swapping is
#'   confined to these adapters. Small supersaturated differences are capped
#'   consistently rather than retained within a tolerance.
#' @param hour,solar_time Legacy timestamp/date-noon selection.
#' @param engine Legacy batch or scalar reference selection.
#' @param diagnostics Return legacy solver diagnostics where supported.
#' @param root_tolerance,residual_tolerance Independent numerical tolerances.
#' @param dewpoint_tolerance Deprecated validation tolerance; accepted and
#'   validated, while canonical dew-point policy is applied exactly.
#' @param pressure Atmospheric pressure in hPa.
#' @param surface_albedo,globe_diameter,min_wind_speed Legacy physical controls.
#' @param workers Number of PSOCK workers.
#' @param direct_fraction Direct share of shortwave radiation.
#' @param relh Relative humidity in percent for scalar component solvers.
#' @param Pair Pressure in hPa for scalar component solvers.
#' @param min.speed Minimum wind speed in m/s for scalar solvers.
#' @param propDirect Direct shortwave fraction for scalar solvers.
#' @param zenith Solar zenith in radians for scalar solvers.
#' @param SurfAlbedo Surface albedo for scalar solvers.
#' @param irad Include radiation (1) or omit it (0) in the scalar wet-bulb solver.
#' @return Simple indices and conversions return numeric vectors. Liljegren
#'   returns list(data, Tnwb, Tg), with diagnostics when requested. Bernard
#'   returns list(Tpwb, data). indexShow returns the legacy-shaped catalog.
#' @details swbgt maps to [wbgt_simplified_indoor()], not the ABM formula.
#'   hi maps to corrected NWS Heat Index in Celsius. fTg/fTnwb remain scalar
#'   reference adapters; use the components from [wbgt_liljegren()] in new code.
#' @author Original package: Ana Casanueva, with contributions attributed in
#'   inherited source. Current fork: Yifei Zheng.
#' @name HeatStressR-deprecated
NULL

#' @rdname HeatStressR-deprecated
#' @export
apparentTemp <- function(tas, hurs, wind) {
  .warn_deprecation("apparentTemp", "apparent_temperature")
  apparent_temperature(tas, hurs, wind)
}
#' @rdname HeatStressR-deprecated
#' @export
effectiveTemp <- function(tas, hurs, wind) {
  .warn_deprecation("effectiveTemp", "effective_temperature")
  effective_temperature(tas, hurs, wind)
}
#' @rdname HeatStressR-deprecated
#' @export
discomInd <- function(tas, hurs) {
  .warn_deprecation("discomInd", "discomfort_index")
  discomfort_index(tas, hurs)
}
#' @rdname HeatStressR-deprecated
#' @export
hi <- function(tas, hurs) {
  .warn_deprecation("hi", "heat_index_rothfusz")
  heat_index_rothfusz(tas, hurs)
}
#' @rdname HeatStressR-deprecated
#' @export
swbgt <- function(tas, hurs) {
  .warn_deprecation("swbgt", "wbgt_simplified_indoor")
  wbgt_simplified_indoor(tas, hurs)
}
#' @rdname HeatStressR-deprecated
#' @export
wbt.Stull <- function(tas, hurs) {
  .warn_deprecation("wbt.Stull", "wet_bulb_stull")
  wet_bulb_stull(tas, hurs)
}
#' @rdname HeatStressR-deprecated
#' @export
dewp2hurs <- function(tas, dewp) {
  .warn_deprecation("dewp2hurs", "relative_humidity")
  relative_humidity(tas, dewp)
}
#' @rdname HeatStressR-deprecated
#' @export
tashurs2vap.pres <- function(tas, hurs) {
  .warn_deprecation("tashurs2vap.pres", "vapour_pressure")
  vapour_pressure(tas, hurs)
}
# Unexported inherited helper, removable with the compatibility layer.
tashurs2dewp <- function(tas, hurs) .dew_point_c(tas, hurs)

#' @rdname HeatStressR-deprecated
#' @export
wbgt.Bernard <- function(tas, dewp, tolerance = 1e-4, noNAs = TRUE, swap = FALSE) {
  .warn_deprecation("wbgt.Bernard", "wbgt_bernard")
  x <- .legacy_swap(tas, dewp, noNAs, swap)
  result <- .evaluate_method("wbgt_bernard", list(tas = x$tas, dewp = x$dewp),
    options = list(dewpoint_policy = x$policy, tolerance = tolerance), return_components = TRUE)
  list(Tpwb = result$components$tpwb, data = result$values)
}

#' @rdname HeatStressR-deprecated
#' @export
wbgt.Liljegren <- function(tas, dewp, wind, radiation, dates, lon, lat,
                           tolerance = 1e-4, noNAs = TRUE, swap = FALSE, hour = FALSE,
                           engine = c("batch", "scalar"), diagnostics = FALSE,
                           root_tolerance = NULL, residual_tolerance = NULL,
                           dewpoint_tolerance = NULL, pressure = 1010,
                           surface_albedo = 0.45, globe_diameter = 0.0508,
                           min_wind_speed = 0.13, workers = 1L,
                           solar_time = "timestamp", direct_fraction = 0.8) {
  .warn_deprecation("wbgt.Liljegren", "wbgt_liljegren")
  .logical_control(diagnostics, "diagnostics")
  hour <- resolve_solar_time(hour, solar_time, !missing(hour), !missing(solar_time))
  validate_tolerance(tolerance, "tolerance")
  if (!is.null(dewpoint_tolerance)) validate_tolerance(dewpoint_tolerance, "dewpoint_tolerance")
  engine <- match.arg(engine)
  workers <- validate_workers(workers)
  if (engine == "scalar" && workers > 1L) stop("'workers' greater than 1 requires engine = 'batch'", call. = FALSE)
  .assert(length(tas) == length(dewp) && length(dewp) == length(wind) && length(wind) == length(radiation),
    "Input vectors do not have the same length")
  .assert(length(tas) > 0L, "Input vectors must not be empty")
  .assert(length(dates) == length(tas), "'dates' must have the same length as the meteorological inputs")
  for (name in c("lon", "lat", "pressure", "direct_fraction")) {
    value <- get(name)
    .assert(is.numeric(value) && length(value) %in% c(1L, length(tas)),
      paste0("'", name, "' must be a numeric scalar or match the meteorological input length"))
  }
  x <- .legacy_swap(tas, dewp, noNAs, swap)
  control <- .liljegren_controls(list(
    root_tolerance = if (is.null(root_tolerance)) tolerance * 0.01 else root_tolerance,
    residual_tolerance = if (is.null(residual_tolerance)) tolerance else residual_tolerance,
    surface_albedo = surface_albedo, globe_diameter = globe_diameter, min_wind_speed = min_wind_speed))
  options <- list(control = control, workers = workers, engine = engine,
    diagnostics = diagnostics, dewpoint_policy = x$policy)
  result <- .evaluate_method("wbgt_liljegren", list(tas = x$tas, dewp = x$dewp,
    wind_2m = wind, radiation = radiation, time = .legacy_times(dates, hour),
    lon = lon, lat = lat, pressure = pressure, direct_fraction = direct_fraction), diagnostics,
    options, return_components = TRUE)
  # Components are part of the legacy return even when solver diagnostics are off.
  out <- list(data = result$values, Tnwb = result$components$tnwb, Tg = result$components$tg)
  if (diagnostics) {
    out$diagnostics <- result$diagnostics$solver
    time_missing <- result$diagnostics$rows$input_status == "missing_input" &
      result$diagnostics$rows$input_reason == "time"
    out$diagnostics$input_status[time_missing] <- "missing_date"
    out$diagnostics$dewpoint_adjusted <- out$diagnostics$dewpoint_adjusted | x$adjusted
  }
  out
}

#' @rdname HeatStressR-deprecated
#' @export
calZenith <- function(dates, lon, lat, hour = FALSE, solar_time = "timestamp") {
  .warn_deprecation("calZenith", "solar_zenith")
  hour <- resolve_solar_time(hour, solar_time, !missing(hour), !missing(solar_time))
  .assert(length(lon) == 1L, "'lon' should be a single finite numeric value")
  .assert(length(lat) == 1L, "'lat' should be a single finite numeric value")
  solar_zenith(.legacy_times(dates, hour), lon, lat)
}

.legacy_component_inputs <- function(method, inputs) {
  p <- .prepare_inputs(inputs)
  .assert(p$n <= 1L, "Legacy component solvers require scalar inputs")
  if ("dewp" %in% names(inputs)) p <- .apply_dewpoint_policy(p, "cap")
  else p$adjusted <- rep(FALSE, p$n)
  .warn_method_rows(method, p$status, rep("unknown", p$n), p$adjusted, rep(FALSE, p$n))
  p
}

#' @rdname HeatStressR-deprecated
#' @export
fTg <- function(tas, relh, Pair, wind, min.speed, radiation, propDirect,
                zenith, SurfAlbedo = 0.45, tolerance = 1e-4, globe_diameter = 0.0508) {
  .warn_deprecation("fTg", "wbgt_liljegren")
  .liljegren_controls(list(surface_albedo = SurfAlbedo, globe_diameter = globe_diameter,
    min_wind_speed = min.speed, root_tolerance = tolerance * 0.01,
    residual_tolerance = tolerance))
  p <- .legacy_component_inputs("fTg", list(tas = tas, hurs = relh, pressure = Pair,
    wind = wind, radiation = radiation, direct_fraction = propDirect, zenith = zenith))
  if (!p$n) return(numeric())
  if (!p$valid) return(NA_real_)
  x <- p$inputs
  fTg_solution(x$tas, x$hurs, x$pressure, x$wind, min.speed, x$radiation,
    x$direct_fraction, x$zenith, SurfAlbedo, tolerance, globe_diameter = globe_diameter)$root
}
#' @rdname HeatStressR-deprecated
#' @export
fTnwb <- function(tas, dewp, relh, Pair, wind, min.speed, radiation, propDirect,
                  zenith, irad = 1, SurfAlbedo = 0.45, tolerance = 1e-4) {
  .warn_deprecation("fTnwb", "wbgt_liljegren")
  .liljegren_controls(list(surface_albedo = SurfAlbedo, min_wind_speed = min.speed,
    root_tolerance = tolerance * 0.01, residual_tolerance = tolerance))
  .assert(is.numeric(irad) && length(irad) == 1L && !is.na(irad) && irad %in% c(0, 1),
    "'irad' must be 0 or 1")
  p <- .legacy_component_inputs("fTnwb", list(tas = tas, dewp = dewp, hurs = relh,
    pressure = Pair, wind = wind, radiation = radiation, direct_fraction = propDirect,
    zenith = zenith))
  if (!p$n) return(numeric())
  if (!p$valid) return(NA_real_)
  x <- p$inputs
  solution <- fTnwb_solution(x$tas, x$dewp, x$hurs, x$pressure, x$wind, min.speed,
    x$radiation, x$direct_fraction, x$zenith, irad, SurfAlbedo, tolerance)
  if (solution$converged) solution$root else NA_real_
}

#' @rdname HeatStressR-deprecated
#' @export
indexShow <- function() {
  .warn_deprecation("indexShow", "heat_methods")
  rows <- lapply(names(.method_registry), function(name) {
    m <- .method_registry[[name]]
    legacy <- names(.legacy_endpoints)[.legacy_endpoints == name]
    code <- if (name == "wbgt_bernard") "wbgt_shade" else if (name == "wbgt_liljegren") "wbgt_sun" else
      if (name == "wet_bulb_stull") "wbt" else if (length(legacy)) legacy[1L] else name
    data.frame(code = code, longname = m$longname,
      indexfun = if (length(legacy)) legacy[1L] else name,
      tas = as.integer("tas" %in% m$inputs), dewp = as.integer("dewp" %in% m$inputs),
      hurs = as.integer("hurs" %in% m$inputs), wind = as.integer(any(c("wind_10m", "wind_2m") %in% m$inputs)),
      radiation = as.integer("radiation" %in% m$inputs), units = m$units, stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}
