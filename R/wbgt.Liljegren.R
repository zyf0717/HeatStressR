#' Calculation of wet bulb globe temperature, following Liljegren's method.
#' 
#' Calculation of wet bulb globe temperature from air temperature, dew point temperature, radiation and wind. 
#' 
#' @param dates vector of dates, `POSIXct`/`POSIXlt` instants, or ISO 8601
#' datetime strings. With `hour = TRUE`, offset-bearing ISO 8601 strings are
#' normalized to UTC.
#' Values must have the same length and row order as the meteorological input
#' vectors.
#' @param noNAs logical, should NAs be introduced when dewp>tas? If TRUE specify how to deal in those cases (swap argument)
#' @param swap logical, should \code{tas >= dewp} be enforced by swapping? Otherwise, dewp is set to tas. This argument is needed when noNAs=T.
#' @param engine Numerical solver engine. \code{"scalar"} is the default corrected
#' reference implementation. \code{"batch"} uses the experimental vectorized
#' safeguarded root solver with automatic scalar fallback for unresolved rows.
#' @param diagnostics logical; return solver metadata in addition to the usual result.
#' @param workers number of PSOCK worker processes for \code{engine = "batch"}.
#' Must be an integer from 1 through the detected logical CPU count. The default
#' of 1 preserves sequential batch execution; values greater than 1 always use
#' the requested number of workers for non-empty batch inputs.
#' @param root_tolerance numerical precision (K) used to locate heat-balance roots.
#' @param residual_tolerance maximum accepted absolute heat-balance residual (K).
#' Must be greater than zero and no greater than 0.01.
#' @param dewpoint_tolerance permitted dewpoint-versus-air-temperature difference
#' (degrees C) used by the dewpoint policy.
#' @param pressure atmospheric pressure in hPa. Supply one value or a vector
#' aligned with the meteorological inputs; defaults to 1010 hPa.
#' @param surface_albedo surface shortwave albedo. Defaults to 0.45, matching
#' the original Liljegren C implementation.
#' @param globe_diameter black-globe diameter in m. Defaults to 0.0508 m,
#' matching the original Liljegren C implementation.
#' @param min_wind_speed lower bound applied to wind speed in m/s. Defaults to
#' 0.13 m/s, matching the original Liljegren C implementation.
#' @param gmt_offset optional local-standard-time offset from GMT, in hours
#' (`LST - GMT`). Use only when `dates` contains local standard clock times;
#' timezone-aware timestamps and ISO 8601 offset strings are normalized to UTC
#' automatically. Do not combine it with an offset-bearing ISO 8601 string.
#' @param averaging_period averaging interval in minutes. Solar position is
#' evaluated at its midpoint; defaults to 0.
#' @inheritParams fTnwb
#' @inheritParams calZenith
#' @importFrom stats optimize
#' 
#' @return A list of:
#' @return $data: wet bulb globe temperature in degC
#' @return $Tnwb: natural wet bulb temperature (Tnwb) in degC
#' @return $Tg: globe temperature in degC
#' @author A.Casanueva (21.02.2017).
#' @details This corresponds to the implementation for outdoors or in the sun conditions (Liljegren et al. 2008). Original fortran code by James C. Liljegren, translated by Bruno Lemke into Visual Basic (VBA) and Ana Casanueva into R.
#' `dates` must have the same length and row order as the meteorological input vectors.
#' Root-location precision, residual validation, and dewpoint validation are
#' controlled independently. Relaxing \code{residual_tolerance} accepts only
#' candidate roots that were found; it cannot recover unbracketed or non-finite
#' solves. Complete WBGT requires both validated component roots, but a validated
#' Tg or Tnwb value is retained when the other component fails.
#' Solar forcing is set to zero when the solar elevation is not positive.
#' Diagnostics flag supplied radiation greater than 15 W/m2 at zenith angles
#' greater than 1.54 radians as \code{solar_geometry_mismatch}.
#' Each component diagnostic includes convergence, evaluations, final residual,
#' failure reason, fallback use, initial/final brackets, endpoint residuals, and
#' resolved root/residual tolerances. \code{complete_wbgt} identifies rows with
#' both validated component roots.
#' With \code{diagnostics = TRUE}, all row-level diagnostic vectors match the
#' input length. \code{input_status} describes filtering, while per-solver
#' \code{converged} and \code{fallback_reason} describe numerical solving.
#' @export
#' 
#' @examples \dontrun{ 
#' # load the meteorological variables for example data in Salamanca:
#' data("data_obs") 
#' wbgt.outdoors <- wbgt.Liljegren(tas=data_obs$tasmean, dewp=data_obs$dewp, 
#' wind=data_obs$wind, radiation=data_obs$solar, dates= data_obs$Dates, lon=-5.66, lat=40.96)
#' }
#' 

wbgt.Liljegren <- function(tas, dewp, wind, radiation, dates, lon, lat, tolerance=1e-4, 
                           noNAs=TRUE, swap=FALSE, hour=FALSE,
                           engine = c("scalar", "batch"), diagnostics = FALSE,
                           root_tolerance = NULL, residual_tolerance = NULL,
                           dewpoint_tolerance = NULL, pressure = 1010,
                           surface_albedo = 0.45, globe_diameter = 0.0508,
                           min_wind_speed = 0.13, gmt_offset = NULL,
                           averaging_period = 0, workers = 1L){

  
  ##################################################
  ##################################################
  # Assumptions
  propDirect <- 0.8  # Assume a proportion of direct radiation = direct/(diffuse + direct)
  
  ##################################################
  ##################################################
  # Assertion statements
  assertthat::assert_that(is.logical(hour) && length(hour) == 1 && !is.na(hour),
    msg="'hour' should be a single logical value")
  assertthat::assert_that(is.logical(noNAs) && length(noNAs) == 1 && !is.na(noNAs),
    msg="'noNAs' should be a single logical value")
  assertthat::assert_that(is.logical(swap) && length(swap) == 1 && !is.na(swap),
    msg="'swap' should be a single logical value")
  assertthat::assert_that(is.logical(diagnostics) && length(diagnostics) == 1 && !is.na(diagnostics),
    msg="'diagnostics' should be a single logical value")
  validate_tolerance(tolerance, "tolerance")
  root_tolerance <- if (is.null(root_tolerance)) tolerance * 0.01 else root_tolerance
  residual_tolerance <- if (is.null(residual_tolerance)) tolerance else residual_tolerance
  dewpoint_tolerance <- if (is.null(dewpoint_tolerance)) tolerance else dewpoint_tolerance
  validate_tolerance(root_tolerance, "root_tolerance")
  validate_tolerance(residual_tolerance, "residual_tolerance", maximum = 0.01)
  validate_tolerance(dewpoint_tolerance, "dewpoint_tolerance")
  engine <- match.arg(engine)
  workers <- validate_workers(workers)
  if (engine != "batch" && workers > 1L)
    stop("'workers' greater than 1 requires engine = 'batch'")
  assertthat::assert_that(length(tas)==length(dewp) & length(dewp)==length(wind)
                          & length(wind)==length(radiation), 
                          msg="Input vectors do not have the same length")
  assertthat::assert_that(length(tas) > 0, msg="Input vectors must not be empty")
  assertthat::assert_that(length(dates) == length(tas),
                          msg="'dates' must have the same length as the meteorological inputs")
  ndates <- length(tas)
  assertthat::assert_that(is.numeric(pressure) && length(pressure) %in% c(1L, ndates),
    msg="'pressure' must be a numeric scalar or match the meteorological input length")
  assertthat::assert_that(all((is.na(pressure) & !is.nan(pressure)) |
    (is.finite(pressure) & pressure > 0)),
    msg="'pressure' must contain only positive finite values or NA")
  assertthat::assert_that(is.numeric(surface_albedo) && length(surface_albedo) == 1L &&
    is.finite(surface_albedo) && surface_albedo >= 0 && surface_albedo <= 1,
    msg="'surface_albedo' must be one finite value between 0 and 1")
  assertthat::assert_that(is.numeric(globe_diameter) && length(globe_diameter) == 1L &&
    is.finite(globe_diameter) && globe_diameter > 0,
    msg="'globe_diameter' must be one positive finite value")
  assertthat::assert_that(is.numeric(min_wind_speed) && length(min_wind_speed) == 1L &&
    is.finite(min_wind_speed) && min_wind_speed >= 0,
    msg="'min_wind_speed' must be one non-negative finite value")
  assertthat::assert_that(propDirect < 1, msg="'propDirect' should be [0,1]")  
  assertthat::assert_that(is.numeric(lon) && length(lon) == 1 && is.finite(lon),
    msg="'lon' should be one finite number")
  assertthat::assert_that(is.numeric(lat) && length(lat) == 1 && is.finite(lat),
    msg="'lat' should be one finite number")
  assertthat::assert_that(lon <= 180 & lon >=-180, msg="Invalid lon")
  assertthat::assert_that(lat <= 90 & lat >=-90, msg="Invalid lat")
  
  ######################
  ######################
  Pair <- rep(pressure, length.out = ndates)
  MinWindSpeed <- min_wind_speed
  Tnwb <- rep(NA_real_, ndates)
  Tg <- rep(NA_real_, ndates)

  # Solar geometry depends only on the aligned timestamps and coordinates.
  # Compute it once before entering the numerical solver loop.
  zenith_rad <- degToRad(calZenith(dates, lon, lat, hour = hour,
    gmt_offset = gmt_offset, averaging_period = averaging_period))
  
  # Do not allow negative wind and radiation
  radiation[radiation<0] <- 0
  wind[wind<0] <- 0
  solar_geometry_mismatch <- !is.na(radiation) & !is.na(zenith_rad) &
    radiation > 15 & zenith_rad > 1.54
  radiation[!is.na(zenith_rad) & cos(zenith_rad) <= 0] <- 0
  
  # Filter data to calculate the WBGT with optimization function
  xmask <- !is.na(tas + dewp + wind + radiation + Pair) & !is.na(zenith_rad)
  input_status <- rep("attempted", ndates)
  input_status[is.na(tas) | is.na(dewp) | is.na(wind) | is.na(radiation) | is.na(Pair)] <-
    "missing_input"
  input_status[input_status == "attempted" & is.na(zenith_rad)] <- "missing_date"
  
  if (noNAs & swap){
    tastmp <- pmax(tas, dewp)
    dewp <- pmin(tas, dewp)
    tas <- tastmp
  } else if(noNAs & !swap){
    noway_idx <- which((dewp - tas) > dewpoint_tolerance)
    dewp[noway_idx] <- tas[noway_idx]
  } else if(!noNAs){
    xmask <- xmask & tas >= dewp
    input_status[input_status == "attempted" & !is.na(tas) & !is.na(dewp) &
      dewp > tas] <- "invalid_dewpoint"
  }
  input_valid <- xmask
 
  # Calculate relative humidity from air temperature and dew point temperature
  relh <- dewp2hurs(tas,dewp) # input in degC, output in %

  
  # **************************************
  # *** Calculation of the Tg and Tnwb ***
  # **************************************
  valid_idx <- which(xmask)
  Tg.converged <- rep(NA, ndates)
  Tnwb.converged <- rep(NA, ndates)
  Tg.evaluations <- rep(NA_integer_, ndates)
  Tnwb.evaluations <- rep(NA_integer_, ndates)
  Tg.final.residual <- rep(NA_real_, ndates)
  Tnwb.final.residual <- rep(NA_real_, ndates)
  Tg.failure.reason <- rep("not_attempted", ndates)
  Tnwb.failure.reason <- rep("not_attempted", ndates)
  effective_workers <- workers
  if (length(valid_idx)) {
    if (engine == "batch") {
      batch_result <- solve_liljegren_batch(
        tas = tas[valid_idx], dewp = dewp[valid_idx], relh = relh[valid_idx],
        Pair = Pair[valid_idx], wind = wind[valid_idx], radiation = radiation[valid_idx],
        zenith = zenith_rad[valid_idx], workers = workers,
        min_wind_speed = MinWindSpeed, tolerance = tolerance,
        root_tolerance = root_tolerance, residual_tolerance = residual_tolerance,
        surface_albedo = surface_albedo, globe_diameter = globe_diameter,
        prop_direct = propDirect
      )
      Tg.batch <- batch_result$Tg
      Tnwb.batch <- batch_result$Tnwb
      effective_workers <- batch_result$workers
      Tg[valid_idx] <- Tg.batch
      Tnwb[valid_idx] <- Tnwb.batch
      Tg.converged[valid_idx] <- attr(Tg.batch, "converged")
      Tnwb.converged[valid_idx] <- attr(Tnwb.batch, "converged")
      Tg.failure.reason[valid_idx] <- attr(Tg.batch, "failure_reason")
      Tnwb.failure.reason[valid_idx] <- attr(Tnwb.batch, "failure_reason")
    } else {
      Tg.solution <- lapply(valid_idx, function(i) suppressWarnings(fTg_solution(tas[i], relh[i], Pair[i],
        wind[i], MinWindSpeed, radiation[i], propDirect, zenith_rad[i],
        tolerance = tolerance, root_tolerance = root_tolerance,
        residual_tolerance = residual_tolerance, SurfAlbedo = surface_albedo,
        globe_diameter = globe_diameter)))
      Tnwb.solution <- lapply(valid_idx, function(i) suppressWarnings(fTnwb_solution(tas[i], dewp[i],
        relh[i], Pair[i], wind[i], MinWindSpeed, radiation[i], propDirect,
        zenith_rad[i], tolerance = tolerance, root_tolerance = root_tolerance,
        residual_tolerance = residual_tolerance, SurfAlbedo = surface_albedo)))
      Tg[valid_idx] <- vapply(Tg.solution, function(x) {
        if (x$converged) x$root else NA_real_
      }, numeric(1))
      Tnwb[valid_idx] <- vapply(Tnwb.solution, function(x) {
        if (x$converged) x$root else NA_real_
      }, numeric(1))
      Tg.converged[valid_idx] <- vapply(Tg.solution, `[[`, logical(1), "converged")
      Tnwb.converged[valid_idx] <- vapply(Tnwb.solution, `[[`, logical(1), "converged")
      Tg.failure.reason[valid_idx] <- vapply(Tg.solution, `[[`, character(1), "failure_reason")
      Tnwb.failure.reason[valid_idx] <- vapply(Tnwb.solution, `[[`, character(1), "failure_reason")
      Tg.evaluations[valid_idx] <- vapply(Tg.solution, `[[`, integer(1), "evaluations")
      Tnwb.evaluations[valid_idx] <- vapply(Tnwb.solution, `[[`, integer(1), "evaluations")
      Tg.final.residual[valid_idx] <- vapply(Tg.solution, `[[`, numeric(1), "residual")
      Tnwb.final.residual[valid_idx] <- vapply(Tnwb.solution, `[[`, numeric(1), "residual")
    }
  }
  Tg.failed <- input_valid & !Tg.converged
  Tnwb.failed <- input_valid & !Tnwb.converged
  if (any(Tg.failed | Tnwb.failed)) {
    reason_counts <- function(reasons, failed) {
      counts <- table(factor(reasons[failed], levels = c("unbracketed", "non_finite", "residual_validation")))
      sprintf("  unbracketed: %d\n  non-finite: %d\n  residual-invalid: %d",
        counts[["unbracketed"]], counts[["non_finite"]], counts[["residual_validation"]])
    }
    warning(sprintf(
      "WBGT heat-balance solving failed for %d of %d attempted rows.\nTg:\n%s\nTnwb:\n%s\nComplete WBGT was set to NA for affected rows. Validated component temperatures were retained. Use diagnostics = TRUE for row-level details.",
      sum(Tg.failed | Tnwb.failed), sum(input_valid),
      reason_counts(Tg.failure.reason, Tg.failed),
      reason_counts(Tnwb.failure.reason, Tnwb.failed)
    ), call. = FALSE)
  }
  # *******************************
  # *** Calculation of the WBGT ***
  # *******************************
  wbgt.value <- ifelse(is.na(Tg) | is.na(Tnwb), NA_real_,
    0.7 * Tnwb + 0.2 * Tg + 0.1 * tas)
  wbgt <- list(data = wbgt.value,
               Tnwb = Tnwb,
               Tg = Tg)
  

  if (diagnostics) {
    wbgt$diagnostics <- if (engine == "batch") {
      list(engine = "batch", workers = effective_workers, attempted = input_valid, input_status = input_status,
        Tg = if (length(valid_idx)) {
          expand_solver_diagnostics(Tg.batch, valid_idx, ndates)
        } else {
          expand_solver_diagnostics(numeric(), integer(), ndates)
        }, Tnwb = if (length(valid_idx)) {
          expand_solver_diagnostics(Tnwb.batch, valid_idx, ndates)
        } else {
          expand_solver_diagnostics(numeric(), integer(), ndates)
        })
    } else {
      list(engine = "scalar", workers = effective_workers, attempted = input_valid, input_status = input_status,
        Tg = scalar_solver_diagnostics(if (length(valid_idx)) Tg.solution else list(), valid_idx, ndates),
        Tnwb = scalar_solver_diagnostics(if (length(valid_idx)) Tnwb.solution else list(), valid_idx, ndates))
    }
    wbgt$diagnostics$complete_wbgt <- wbgt$diagnostics$Tg$converged &
      wbgt$diagnostics$Tnwb$converged
    wbgt$diagnostics$solar_geometry_mismatch <- solar_geometry_mismatch
  }
  wbgt
}
