#' Calculation of the natural wet bulb temperature.
#' 
#' Calculation of the natural wet bulb temperature.
#' 
#' @param tas vector of temperature in degC.
#' @param dewp vector of dewpoint temperature in degC.
#' @param wind vector of wind speed in m/s.
#' @param relh vector of relative humidity in \%.
#' @param radiation vector of solar shortwave downwelling radiation in W/m2.
#' @param propDirect proportion of direct radiation = direct/(diffuse + direct).
#' @param zenith zenith angle in radians.
#' @param SurfAlbedo (optional) albedo in the surface. Default: 0.45.
#' @param tolerance (optional) tolerance value for the iteration. Default: 1e-4.
#' @param irad (optional): include radiation (1) or not (irad=0, psychrometric web bulb temp). Default: 1.
#' @inheritParams h_cylinder_in_air
#' 
#' @return Natural wet bulb globe temperature in degC.
#' @author Ana Casanueva (05.01.2017).
#' @details Original fortran code by James C. Liljegren, translated by Bruno Lemke into Visual Basic (VBA).
#' @export
#' 


fTnwb_solution <- function(tas, dewp, relh, Pair, wind, min.speed, radiation,
                           propDirect, zenith, irad = 1, SurfAlbedo = 0.45,
                           tolerance = 1e-4, root_tolerance = tolerance * 0.01,
                           residual_tolerance = tolerance) {
  

  # Physical constants
  stefanb <- STEFAN_BOLTZMANN
  r.air <- R_DRY_AIR
  
  # Wick constants
  emis.wick <- 0.95 # emissivity
  alb.wick <- 0.4 # albedo
  diam.wick <- 0.007 # diameter (in m)
  len.wick <- 0.0254 # length (in m)
  
  # Surface constants
  emis.sfc <- 0.999
  alb.sfc <- SurfAlbedo
  
  # Fix up out-of bounds problems with zenith
  if(zenith <= 0) zenith <- 0.0000000001
  if(radiation > 0 & zenith > 1.57) zenith <- 1.57 # 90°
  if(radiation > 15 & zenith > 1.54)  zenith <- 1.54 # 88°
  if(radiation > 900 & zenith > 1.52) zenith <- 1.52 # 87°
  if(radiation < 10 & zenith == 1.57) radiation <- 0
  
  # Change units
  Tdew <- dewp + 273.15 # to Kelvin
  Tair <- tas + 273.15 # to Kelvin
  RH <- relh * 0.01 # to fraction
  
  # Calculate vapour pressure
  eair <- RH * esat(Tair) 
  
  # Calculate the atmospheric emissivity
  emis.atm <- emis_atm(Tair, RH)
  
  # Set values for iteration
  Tsfc <- Tair
  # Density of the air
  density <- Pair * 100 / (Tair * r.air)
  effective.wind <- max(wind, min.speed)
  viscosity.air <- viscosity(Tair)
  diffusivity.coefficient <- diffusivity_coefficient(Pair)
  longwave <- 0.5 * (emis.atm * Tair ^ 4 + emis.sfc * Tsfc ^ 4)
  solar <- (1 - alb.wick) * radiation * ((1 - propDirect) *
    (1 + 0.25 * diam.wick / len.wick) + ((tan(zenith) / 3.1416) +
    0.25 * diam.wick / len.wick) * propDirect + alb.sfc)
  
  evaluations <- 0L
  residual <- function(Twb) {
    evaluations <<- evaluations + 1L
    fTnwb_residual(Twb, Tair, Pair, effective.wind, eair, density,
      viscosity.air, diffusivity.coefficient, longwave, solar, irad,
      diam.wick, emis.wick)
  }

  # The historical Tdew - 1 to Tair + 1 interval is only an initial guess.
  lower <- Tdew - 1
  upper <- Tair + 1
  f.lower <- residual(lower)
  f.upper <- residual(upper)
  initial.lower <- lower
  initial.upper <- upper
  minimum <- Tair - 100
  maximum <- Tair + 100
  while (is.finite(f.lower) && is.finite(f.upper) && f.lower * f.upper > 0 &&
         (lower > minimum || upper < maximum)) {
    if (lower > minimum) {
      lower <- max(lower - 10, minimum)
      f.lower <- residual(lower)
    }
    if (f.lower * f.upper > 0 && upper < maximum) {
      upper <- min(upper + 10, maximum)
      f.upper <- residual(upper)
    }
  }
  if (!is.finite(f.lower) || !is.finite(f.upper) || f.lower * f.upper > 0) {
    warning("fTnwb could not bracket a finite heat-balance root", call. = FALSE)
    return(list(root = NA_real_, candidate_root = NA_real_, evaluations = evaluations,
      residual = NA_real_, initial_lower = initial.lower, initial_upper = initial.upper,
      final_lower = lower, final_upper = upper, lower_residual = f.lower,
      upper_residual = f.upper, root_tolerance = root_tolerance,
      residual_tolerance = residual_tolerance,
      converged = FALSE, failure_reason = if (is.finite(f.lower) &&
        is.finite(f.upper)) "unbracketed" else "non_finite"))
  }
  root <- stats::uniroot(residual, c(lower, upper), tol = root_tolerance)$root
  final.residual <- residual(root)
  converged <- valid_solver_result(root, final.residual, residual_tolerance)
  list(root = if (converged) root - 273.15 else NA_real_,
       candidate_root = root - 273.15, evaluations = evaluations,
       residual = final.residual, initial_lower = initial.lower, initial_upper = initial.upper,
       final_lower = lower, final_upper = upper, lower_residual = f.lower,
       upper_residual = f.upper, root_tolerance = root_tolerance,
       residual_tolerance = residual_tolerance, converged = converged,
       failure_reason = if (converged) "none" else "residual_validation")
}

fTnwb <- function(tas, dewp, relh, Pair, wind, min.speed, radiation, propDirect,
                  zenith, irad = 1, SurfAlbedo = 0.45, tolerance = 1e-4) {
  solution <- fTnwb_solution(tas, dewp, relh, Pair, wind, min.speed, radiation,
    propDirect, zenith, irad, SurfAlbedo, tolerance)
  if (solution$converged) solution$root else NA_real_
  
}
