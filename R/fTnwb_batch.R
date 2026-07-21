fTnwb_batch <- function(tas, dewp, relh, Pair, wind, min.speed, radiation,
                        propDirect, zenith, irad = 1, SurfAlbedo = 0.45,
                        tolerance = 1e-4, max_iterations = 100L, damping = 0.25,
                        root_solver = vector_uniroot, scalar_solver = fTnwb_solution,
                        root_tolerance = tolerance * 0.01,
                        residual_tolerance = tolerance) {
  n <- length(tas)
  if (!all(vapply(list(dewp, relh, wind, radiation, zenith), length,
    integer(1)) == n) || !all(vapply(list(Pair), length, integer(1)) %in% c(1L, n)))
    stop("fTnwb_batch inputs must have the same length")
  Pair <- rep(Pair, length.out = n)
  propDirect <- rep(propDirect, length.out = n)
  irad <- rep(irad, length.out = n)
  SurfAlbedo <- rep(SurfAlbedo, length.out = n)
  emis.wick <- 0.95
  alb.wick <- 0.4
  diam.wick <- 0.007
  len.wick <- 0.0254
  zenith[zenith <= 0] <- 1e-10
  zenith[radiation > 0 & zenith > 1.57] <- 1.57
  zenith[radiation > 15 & zenith > 1.54] <- 1.54
  zenith[radiation > 900 & zenith > 1.52] <- 1.52
  radiation[radiation < 10 & zenith == 1.57] <- 0
  Tair <- tas + 273.15
  Tdew <- dewp + 273.15
  wind <- pmax(wind, min.speed)
  RH <- relh * 0.01
  eair <- RH * esat(Tair)
  density <- Pair * 100 / (Tair * R_DRY_AIR)
  viscosity.air <- viscosity(Tair)
  diffusivity.coefficient <- diffusivity_coefficient(Pair)
  longwave <- 0.5 * (emis_atm(Tair, RH) * Tair ^ 4 + 0.999 * Tair ^ 4)
  solar <- (1 - alb.wick) * radiation * ((1 - propDirect) *
    (1 + 0.25 * diam.wick / len.wick) + ((tan(zenith) / 3.1416) +
    0.25 * diam.wick / len.wick) * propDirect + SurfAlbedo)
  solve <- root_solver(
    function(value, idx) fTnwb_residual(value, Tair[idx], Pair[idx], wind[idx],
      eair[idx], density[idx], viscosity.air[idx], diffusivity.coefficient[idx],
      longwave[idx], solar[idx], irad[idx], diam.wick, emis.wick),
    lower = Tdew - 1, upper = Tair + 1, lower_limit = Tair - 100,
    upper_limit = Tair + 100, tolerance = root_tolerance, max_iterations = max_iterations
  )
  twb <- solve$root
  batch.residual <- fTnwb_residual(twb, Tair, Pair, wind, eair, density,
    viscosity.air, diffusivity.coefficient, longwave, solar, irad, diam.wick,
    emis.wick)
  batch.valid <- valid_solver_result(twb, batch.residual, residual_tolerance)
  failure.reason <- solve$failure_reason
  fallback.reason <- failure.reason
  residual.invalid <- solve$converged & !batch.valid
  failure.reason[residual.invalid & failure.reason == "none"] <- "residual_validation"
  fallback.reason[residual.invalid & fallback.reason == "none"] <- "residual_validation"
  unresolved <- which(!solve$converged | !batch.valid)
  fallback.evaluations <- integer(n)
  fallback.converged <- rep(NA, n)
  final.lower <- solve$lower
  final.upper <- solve$upper
  final.lower.residual <- solve$lower_residual
  final.upper.residual <- solve$upper_residual
  if (length(unresolved)) {
    fallback <- lapply(unresolved, function(i) suppressWarnings(scalar_solver(
      tas[i], dewp[i], relh[i], Pair[i], wind[i], min.speed, radiation[i],
      propDirect[i], zenith[i], irad[i], SurfAlbedo[i], tolerance,
      root_tolerance, residual_tolerance
    )))
    fallback.converged[unresolved] <- vapply(fallback, `[[`, logical(1), "converged")
    twb[unresolved] <- vapply(fallback, function(x) {
      if (x$converged) x$root + 273.15 else NA_real_
    }, numeric(1))
    fallback.evaluations[unresolved] <- vapply(fallback, `[[`, integer(1), "evaluations")
    scalar.reason <- vapply(fallback, function(x) {
      if (is.null(x$failure_reason)) "scalar_fallback_failed" else x$failure_reason
    }, character(1))
    failure.reason[unresolved] <- scalar.reason
    fallback.reason[unresolved[!fallback.converged[unresolved]]] <- "scalar_fallback_failed"
    extract_numeric <- function(name) vapply(fallback, function(x) {
      if (is.null(x[[name]])) NA_real_ else x[[name]]
    }, numeric(1))
    final.lower[unresolved] <- extract_numeric("final_lower")
    final.upper[unresolved] <- extract_numeric("final_upper")
    final.lower.residual[unresolved] <- extract_numeric("lower_residual")
    final.upper.residual[unresolved] <- extract_numeric("upper_residual")
  }
  final.residual <- fTnwb_residual(twb, Tair, Pair, wind, eair, density,
    viscosity.air, diffusivity.coefficient, longwave, solar, irad, diam.wick,
    emis.wick)
  final.valid <- valid_solver_result(twb, final.residual, residual_tolerance)
  candidate.root <- twb - 273.15
  failure.reason[final.valid] <- "none"
  failure.reason[!final.valid & failure.reason == "none"] <- "residual_validation"
  twb[!final.valid] <- NA_real_
  converged <- final.valid
  result <- twb - 273.15
  attr(result, "batch_iterations") <- solve$iterations
  attr(result, "batch_evaluations") <- solve$evaluations
  attr(result, "bracket_evaluations") <- solve$evaluations - solve$iterations
  attr(result, "fallback_evaluations") <- fallback.evaluations
  attr(result, "total_evaluations") <- solve$evaluations + fallback.evaluations
  attr(result, "evaluations") <- solve$evaluations + fallback.evaluations
  attr(result, "used_fallback") <- seq_len(n) %in% unresolved
  attr(result, "batch_converged") <- solve$converged
  attr(result, "batch_residual") <- batch.residual
  attr(result, "batch_valid") <- batch.valid
  attr(result, "fallback_converged") <- fallback.converged
  attr(result, "converged") <- converged
  attr(result, "final_residual") <- final.residual
  attr(result, "failure_reason") <- failure.reason
  attr(result, "fallback_reason") <- fallback.reason
  attr(result, "lower") <- final.lower
  attr(result, "upper") <- final.upper
  attr(result, "final_lower") <- final.lower
  attr(result, "final_upper") <- final.upper
  attr(result, "initial_lower") <- solve$initial_lower
  attr(result, "initial_upper") <- solve$initial_upper
  attr(result, "lower_residual") <- final.lower.residual
  attr(result, "upper_residual") <- final.upper.residual
  attr(result, "candidate_root") <- candidate.root
  attr(result, "root_tolerance") <- rep(root_tolerance, n)
  attr(result, "residual_tolerance") <- rep(residual_tolerance, n)
  attr(result, "fallback_count") <- length(unresolved)
  attr(result, "iterations") <- solve$iterations
  attr(result, "residual") <- final.residual
  result
}
