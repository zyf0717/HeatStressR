normalize_liljegren_coordinates <- function(lon, lat, n) {
  .assert(is.numeric(lon) && length(lon) %in% c(1L, n) &&
    all(is.na(lon) | is.finite(lon)),
  msg = "'lon' must be one finite number or match the meteorological input length")
  .assert(is.numeric(lat) && length(lat) %in% c(1L, n) &&
    all(is.na(lat) | is.finite(lat)),
  msg = "'lat' must be one finite number or match the meteorological input length")
  .assert(all(lon <= 180 & lon >= -180, na.rm = TRUE), msg = "Invalid lon")
  .assert(all(lat <= 90 & lat >= -90, na.rm = TRUE), msg = "Invalid lat")

  list(lon = rep(lon, length.out = n), lat = rep(lat, length.out = n))
}

.liljegren_zenith <- function(dates, lon, lat) {
  n <- length(dates)
  coordinates <- normalize_liljegren_coordinates(lon, lat, n)
  date_key <- if (inherits(dates, "POSIXt")) as.numeric(dates) else as.character(dates)
  unique_date_index <- !duplicated(date_key)
  date_index <- match(date_key, date_key[unique_date_index])
  terms <- .solar_time_terms(dates[unique_date_index])
  degToRad(calculate_zenith_from_solar_terms(
    terms$utc_minutes[date_index], terms$equation_of_time[date_index],
    terms$declination[date_index], coordinates$lon, coordinates$lat
  ))
}

format_liljegren_failure_counts <- function(counts) sprintf(
  "  unbracketed: %d\n  non-finite: %d\n  residual-invalid: %d",
  counts[["unbracketed"]], counts[["non_finite"]], counts[["residual_validation"]]
)

liljegren_failure_counts <- function(reasons, failed) {
  table(factor(reasons[failed], levels = c("unbracketed", "non_finite", "residual_validation")))
}

.liljegren_core <- function(tas, dewp, wind, radiation, dates, lon, lat,
                            pressure, direct_fraction, control, workers = 1L,
                            engine = "batch", diagnostics = FALSE) {
  # Inputs are aligned and filtered by the public input contract.
  tolerance <- control$residual_tolerance
  root_tolerance <- control$root_tolerance
  residual_tolerance <- control$residual_tolerance
  dewpoint_tolerance <- 0
  surface_albedo <- control$surface_albedo
  globe_diameter <- control$globe_diameter
  min_wind_speed <- control$min_wind_speed
  ndates <- length(tas)
  requested_workers <- workers
  effective_workers <- min(workers, ndates)
  parallel_failure_summary <- NULL
  if (engine == "batch" && effective_workers > 1L) {
    parallel_result <- solve_liljegren_parallel(
      tas = tas, dewp = dewp, wind = wind, radiation = radiation,
      dates = dates, lon = lon, lat = lat,
      pressure = pressure, direct_fraction = direct_fraction,
      workers = effective_workers,
      diagnostics = diagnostics,
      controls = list(
        dewpoint_policy = "na",
        dewpoint_tolerance = dewpoint_tolerance, min_wind_speed = min_wind_speed,
        tolerance = tolerance, root_tolerance = root_tolerance,
        residual_tolerance = residual_tolerance, surface_albedo = surface_albedo,
        globe_diameter = globe_diameter
      )
    )
    wbgt.value <- parallel_result$data
    Tg <- parallel_result$Tg
    Tnwb <- parallel_result$Tnwb
    effective_workers <- parallel_result$workers
    if (diagnostics) {
      input_valid <- parallel_result$input_valid
      input_status <- parallel_result$input_status
      solar_geometry_mismatch <- parallel_result$solar_geometry_mismatch
      wind_clamped <- parallel_result$wind_clamped
      radiation_clamped <- parallel_result$radiation_clamped
      radiation_zeroed_below_horizon <- parallel_result$radiation_zeroed_below_horizon
      dewpoint_adjusted <- parallel_result$dewpoint_adjusted
      valid_idx <- parallel_result$valid_idx
      Tg.batch <- parallel_result$Tg.batch
      Tnwb.batch <- parallel_result$Tnwb.batch
      Tg.converged <- rep(NA, ndates)
      Tnwb.converged <- rep(NA, ndates)
      Tg.failure.reason <- rep("not_attempted", ndates)
      Tnwb.failure.reason <- rep("not_attempted", ndates)
      if (length(valid_idx)) {
        Tg.converged[valid_idx] <- attr(Tg.batch, "converged")
        Tnwb.converged[valid_idx] <- attr(Tnwb.batch, "converged")
        Tg.failure.reason[valid_idx] <- attr(Tg.batch, "failure_reason")
        Tnwb.failure.reason[valid_idx] <- attr(Tnwb.batch, "failure_reason")
      }
    } else {
      parallel_failure_summary <- parallel_result$failure_summary
    }
  } else {
  # Reuse timestamp-only terms, then project row-aligned coordinates in one
  # vectorized solar-geometry call before solving.
  zenith_rad <- .liljegren_zenith(dates, lon, lat)
  preprocessed <- preprocess_liljegren_inputs(
    tas, dewp, wind, radiation, pressure, zenith_rad,
    "na", dewpoint_tolerance, diagnostics
  )
  tas <- preprocessed$tas
  dewp <- preprocessed$dewp
  wind <- preprocessed$wind
  radiation <- preprocessed$radiation
  Pair <- preprocessed$Pair
  relh <- preprocessed$relh
  input_valid <- preprocessed$input_valid
  input_status <- preprocessed$input_status
  solar_geometry_mismatch <- preprocessed$solar_geometry_mismatch
  valid_idx <- preprocessed$valid_idx
  if (diagnostics) {
    wind_clamped <- preprocessed$wind_clamped
    radiation_clamped <- preprocessed$radiation_clamped
    radiation_zeroed_below_horizon <- preprocessed$radiation_zeroed_below_horizon
    dewpoint_adjusted <- preprocessed$dewpoint_adjusted
  }
  MinWindSpeed <- min_wind_speed
  Tnwb <- rep(NA_real_, ndates)
  Tg <- rep(NA_real_, ndates)

  # **************************************
  # *** Calculation of the Tg and Tnwb ***
  # **************************************
  Tg.converged <- rep(NA, ndates)
  Tnwb.converged <- rep(NA, ndates)
  Tg.failure.reason <- rep("not_attempted", ndates)
  Tnwb.failure.reason <- rep("not_attempted", ndates)
  if (length(valid_idx)) {
    if (engine == "batch") {
      batch_result <- solve_liljegren_batch(
        tas = tas[valid_idx], dewp = dewp[valid_idx], relh = relh[valid_idx],
        Pair = Pair[valid_idx], wind = wind[valid_idx], radiation = radiation[valid_idx],
        zenith = zenith_rad[valid_idx],
        min_wind_speed = MinWindSpeed, tolerance = tolerance,
        root_tolerance = root_tolerance, residual_tolerance = residual_tolerance,
        surface_albedo = surface_albedo, globe_diameter = globe_diameter,
        prop_direct = direct_fraction[valid_idx]
      )
      Tg.batch <- batch_result$Tg
      Tnwb.batch <- batch_result$Tnwb
      Tg[valid_idx] <- Tg.batch
      Tnwb[valid_idx] <- Tnwb.batch
      Tg.converged[valid_idx] <- attr(Tg.batch, "converged")
      Tnwb.converged[valid_idx] <- attr(Tnwb.batch, "converged")
      Tg.failure.reason[valid_idx] <- attr(Tg.batch, "failure_reason")
      Tnwb.failure.reason[valid_idx] <- attr(Tnwb.batch, "failure_reason")
    } else {
      Tg.solution <- lapply(valid_idx, function(i) suppressWarnings(fTg_solution(tas[i], relh[i], Pair[i],
        wind[i], MinWindSpeed, radiation[i], direct_fraction[i], zenith_rad[i],
        tolerance = tolerance, root_tolerance = root_tolerance,
        residual_tolerance = residual_tolerance, SurfAlbedo = surface_albedo,
        globe_diameter = globe_diameter)))
      Tnwb.solution <- lapply(valid_idx, function(i) suppressWarnings(fTnwb_solution(tas[i], dewp[i],
        relh[i], Pair[i], wind[i], MinWindSpeed, radiation[i], direct_fraction[i],
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
    }
  }
  }
  if (is.null(parallel_failure_summary)) {
    Tg.failed <- input_valid & !Tg.converged
    Tnwb.failed <- input_valid & !Tnwb.converged
    failed_rows <- sum(Tg.failed | Tnwb.failed)
    attempted_rows <- sum(input_valid)
    tg_reason_counts <- format_liljegren_failure_counts(
      liljegren_failure_counts(Tg.failure.reason, Tg.failed)
    )
    tnwb_reason_counts <- format_liljegren_failure_counts(
      liljegren_failure_counts(Tnwb.failure.reason, Tnwb.failed)
    )
  } else {
    failed_rows <- parallel_failure_summary$failed_rows
    attempted_rows <- parallel_failure_summary$attempted_rows
    tg_reason_counts <- format_liljegren_failure_counts(parallel_failure_summary$Tg)
    tnwb_reason_counts <- format_liljegren_failure_counts(parallel_failure_summary$Tnwb)
  }
  if (failed_rows) {
    warning(sprintf(
      "WBGT heat-balance solving failed for %d of %d attempted rows.\nTg:\n%s\nTnwb:\n%s\nComplete WBGT was set to NA for affected rows. Validated component temperatures were retained. Use diagnostics = TRUE for row-level details.",
      failed_rows, attempted_rows, tg_reason_counts, tnwb_reason_counts
    ), call. = FALSE)
  }
  # *******************************
  # *** Calculation of the WBGT ***
  # *******************************
  if (!(engine == "batch" && effective_workers > 1L)) {
    wbgt.value <- ifelse(is.na(Tg) | is.na(Tnwb), NA_real_,
      0.7 * Tnwb + 0.2 * Tg + 0.1 * tas)
  }
  wbgt <- list(data = wbgt.value,
               Tnwb = Tnwb,
               Tg = Tg)
  

  if (diagnostics) {
    wbgt$diagnostics <- if (engine == "batch") {
      list(engine = "batch", workers = effective_workers, requested_workers = requested_workers,
        attempted = input_valid, input_status = input_status,
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
      list(engine = "scalar", workers = effective_workers, requested_workers = requested_workers,
        attempted = input_valid, input_status = input_status,
        Tg = scalar_solver_diagnostics(if (length(valid_idx)) Tg.solution else list(), valid_idx, ndates),
        Tnwb = scalar_solver_diagnostics(if (length(valid_idx)) Tnwb.solution else list(), valid_idx, ndates))
    }
    wbgt$diagnostics$complete_wbgt <- wbgt$diagnostics$Tg$converged &
      wbgt$diagnostics$Tnwb$converged
    wbgt$diagnostics$solar_geometry_mismatch <- solar_geometry_mismatch
    wbgt$diagnostics$wind_clamped <- wind_clamped
    wbgt$diagnostics$radiation_clamped <- radiation_clamped
    wbgt$diagnostics$radiation_zeroed_below_horizon <-
      radiation_zeroed_below_horizon
    wbgt$diagnostics$dewpoint_adjusted <- dewpoint_adjusted
  }
  wbgt
}
