#' Calculation of the globe temperature.
#' 
#' Calculation of the globe temperature.
#' 
#' @inheritParams fTnwb 
#' @return Globe temperature in degC.
#' 
#' @author Ana Casanueva (05.01.2017).
#' @details Original fortran code by James C. Liljegren, translated by Bruno Lemke into Visual Basic (VBA).
#' Uses an adaptively bracketed signed heat-balance residual.
#' @export
#' 


fTg_solution <- function(tas, relh, Pair, wind, min.speed, radiation, propDirect,
                         zenith, SurfAlbedo = 0.45, tolerance = 1e-4,
                         root_tolerance = tolerance * 0.01,
                         residual_tolerance = tolerance,
                         globe_diameter = 0.0508) {

 
  # Physical constants
  stefanb <- 0.000000056696
  cp <- 1003.5 # heat capaticy at constant pressure of dry air
  m.air <- 28.97
  m.h2o <- 18.015
  r.gas <- 8314.34
  r.air <- r.gas / m.air
  ratio <- cp * m.air/ m.h2o
  Pr <- cp / (cp + (1.25 * r.air))
  
  # Globe constants
  emis.globe <- 0.95 # emissivity
  alb.globe <- 0.05 # albedo
  diam.globe <- globe_diameter
  
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
  Tair <- tas + 273.15
  RH <- relh * 0.01
  
  # cosine of zenith angle
  cza <- cos(zenith)
  
  # Set values for iteration
  Tsfc <- Tair
  effective.wind <- max(wind, min.speed)
  longwave <- 0.5 * (emis_atm(Tair, RH) * Tair ^ 4 + emis.sfc * Tsfc ^ 4)
  solar <- radiation / (2 * emis.globe * stefanb) * (1 - alb.globe) *
    (propDirect * (1 / (2 * cza) - 1) + 1 + alb.sfc)
  
  # Locate the root in the fourth-power energy equation. Residual acceptance is
  # evaluated separately in the K-scale fixed-point form.
  evaluations <- 0L
  fr <- function(Tglobe_prev, Tair, Pair) {
    evaluations <<- evaluations + 1L
    fTg_energy_residual(Tglobe_prev, Tair, Pair, effective.wind, longwave, solar,
      diam.globe, emis.globe)
  }
  
  lower <- Tair - 2
  upper <- Tair + 10
  f.lower <- fr(lower, Tair, Pair)
  f.upper <- fr(upper, Tair, Pair)
  initial.lower <- lower
  initial.upper <- upper
  maximum <- Tair + 200
  minimum <- Tair - 200
  while (is.finite(f.lower) && is.finite(f.upper) && f.lower * f.upper > 0) {
    # The residual is decreasing over the physical range: two negative values
    # require a lower bracket, while two positive values require an upper one.
    width <- upper - lower
    if (f.lower < 0 && lower > minimum) {
      lower <- max(lower - width, minimum)
      f.lower <- fr(lower, Tair, Pair)
    } else if (f.upper > 0 && upper < maximum) {
      upper <- min(upper + width, maximum)
      f.upper <- fr(upper, Tair, Pair)
    } else {
      break
    }
  }
  if (!is.finite(f.lower) || !is.finite(f.upper) || f.lower * f.upper > 0) {
    warning("fTg could not bracket a finite heat-balance root", call. = FALSE)
    return(list(root = NA_real_, candidate_root = NA_real_, evaluations = evaluations,
      residual = NA_real_, initial_lower = initial.lower, initial_upper = initial.upper,
      final_lower = lower, final_upper = upper, lower_residual = f.lower,
      upper_residual = f.upper, root_tolerance = root_tolerance,
      residual_tolerance = residual_tolerance,
      converged = FALSE, failure_reason = if (is.finite(f.lower) &&
        is.finite(f.upper)) "unbracketed" else "non_finite"))
  }
  root <- stats::uniroot(fr, c(lower, upper), Tair = Tair, Pair = Pair,
    tol = root_tolerance)$root
  final.residual <- fTg_residual(root, Tair, Pair, effective.wind, longwave,
    solar, diam.globe, emis.globe)
  converged <- valid_solver_result(root, final.residual, residual_tolerance)
  list(root = if (converged) root - 273.15 else NA_real_,
    candidate_root = root - 273.15, evaluations = evaluations,
    residual = final.residual, initial_lower = initial.lower, initial_upper = initial.upper,
    final_lower = lower, final_upper = upper, lower_residual = f.lower,
    upper_residual = f.upper, root_tolerance = root_tolerance,
    residual_tolerance = residual_tolerance, converged = converged,
    failure_reason = if (converged) "none" else "residual_validation")
}

fTg <- function(tas, relh, Pair, wind, min.speed, radiation, propDirect,
                zenith, SurfAlbedo = 0.45, tolerance = 1e-4,
                globe_diameter = 0.0508) {
  fTg_solution(tas, relh, Pair, wind, min.speed, radiation, propDirect,
    zenith, SurfAlbedo, tolerance, globe_diameter = globe_diameter)$root
}
