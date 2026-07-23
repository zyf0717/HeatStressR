max_liljegren_workers <- function() {
  detected <- parallel::detectCores(logical = TRUE)
  if (length(detected) != 1L || is.na(detected) || !is.finite(detected) || detected < 1L)
    return(1L)

  detected <- as.integer(detected)
  if (identical(tolower(Sys.getenv("_R_CHECK_LIMIT_CORES_")), "true"))
    detected <- min(detected, 2L)
  detected
}

validate_workers <- function(workers) {
  if (missing(workers))
    stop("'workers' must be one finite integer")
  if (!is.numeric(workers) || length(workers) != 1L || is.na(workers) ||
      !is.finite(workers) || workers != floor(workers)) {
    stop("'workers' must be one finite integer")
  }
  if (workers < 1L)
    stop("'workers' must be at least 1")

  maximum <- max_liljegren_workers()
  if (workers > maximum)
    stop("'workers' must not exceed the currently permitted worker count (", maximum, ")")
  as.integer(workers)
}

split_liljegren_chunks <- function(n, workers) {
  boundaries <- floor(seq.int(0L, workers) * n / workers)
  lapply(seq_len(workers), function(i) {
    if (boundaries[i] == boundaries[i + 1L]) integer() else
      seq.int(boundaries[i] + 1L, boundaries[i + 1L])
  })
}

solve_liljegren_batch_chunk <- function(chunk, controls) {
  list(
    Tg = fTg_batch(
      chunk$tas, chunk$relh, chunk$Pair, chunk$wind,
      controls$min_wind_speed, chunk$radiation, controls$prop_direct,
      chunk$zenith, tolerance = controls$tolerance,
      root_tolerance = controls$root_tolerance,
      residual_tolerance = controls$residual_tolerance,
      SurfAlbedo = controls$surface_albedo,
      globe_diameter = controls$globe_diameter
    ),
    Tnwb = fTnwb_batch(
      chunk$tas, chunk$dewp, chunk$relh, chunk$Pair, chunk$wind,
      controls$min_wind_speed, chunk$radiation, controls$prop_direct,
      chunk$zenith, tolerance = controls$tolerance,
      root_tolerance = controls$root_tolerance,
      residual_tolerance = controls$residual_tolerance,
      SurfAlbedo = controls$surface_albedo
    )
  )
}

combine_batch_solver_results <- function(results) {
  if (!length(results))
    stop("at least one batch solver result is required")

  expected_attributes <- c(WBGT_DIAGNOSTIC_FIELDS, "fallback_count", "iterations", "residual")
  result_lengths <- vapply(results, length, integer(1))
  for (result in results) {
    attrs <- attributes(result)
    if (!identical(sort(names(attrs)), sort(expected_attributes)))
      stop("batch solver chunks must have consistent diagnostic attributes")
    malformed <- vapply(WBGT_DIAGNOSTIC_FIELDS,
      function(field) length(attrs[[field]]) != length(result), logical(1))
    if (any(malformed))
      stop("batch solver chunk diagnostics must match result lengths: ",
        paste(names(malformed)[malformed], collapse = ", "))
    if (length(attrs$fallback_count) != 1L || length(attrs$iterations) != length(result) ||
        length(attrs$residual) != length(result))
      stop("batch solver chunk compatibility attributes are malformed")
  }

  combined <- unlist(lapply(results, as.numeric), use.names = FALSE)
  for (field in WBGT_DIAGNOSTIC_FIELDS) {
    values <- lapply(results, attr, which = field)
    if (length(unique(vapply(values, typeof, character(1)))) != 1L)
      stop("batch solver chunk diagnostic types differ for ", field)
    attr(combined, field) <- do.call(c, values)
  }
  attr(combined, "fallback_count") <- as.integer(sum(vapply(results,
    function(result) attr(result, "fallback_count"), integer(1))))
  attr(combined, "iterations") <- do.call(c, lapply(results, attr, which = "iterations"))
  attr(combined, "residual") <- do.call(c, lapply(results, attr, which = "residual"))
  if (length(combined) != sum(result_lengths))
    stop("combined batch solver result has an inconsistent length")
  combined
}

solve_liljegren_batch <- function(tas, dewp, relh, Pair, wind, radiation, zenith,
                                  min_wind_speed, tolerance, root_tolerance,
                                  residual_tolerance, surface_albedo, globe_diameter,
                                  prop_direct = 0.8) {
  n <- length(tas)
  if (!all(vapply(list(dewp, relh, Pair, wind, radiation, zenith), length,
    integer(1)) == n)) {
    stop("preprocessed batch inputs must have the same length")
  }
  controls <- list(
    min_wind_speed = min_wind_speed, tolerance = tolerance,
    root_tolerance = root_tolerance, residual_tolerance = residual_tolerance,
    surface_albedo = surface_albedo, globe_diameter = globe_diameter,
    prop_direct = prop_direct
  )
  payload <- list(tas = tas, dewp = dewp, relh = relh, Pair = Pair, wind = wind,
    radiation = radiation, zenith = zenith)

  solve_liljegren_batch_chunk(payload, controls)
}

solve_liljegren_batch_raw_chunk <- function(chunk, controls) {
  n <- length(chunk$tas)
  Pair <- rep(chunk$pressure, length.out = n)
  tas <- chunk$tas
  dewp <- chunk$dewp
  wind <- chunk$wind
  radiation <- chunk$radiation
  zenith <- chunk$zenith

  radiation[radiation < 0] <- 0
  wind[wind < 0] <- 0
  solar_geometry_mismatch <- !is.na(radiation) & !is.na(zenith) &
    radiation > 15 & zenith > 1.54
  radiation[!is.na(zenith) & cos(zenith) <= 0] <- 0

  input_valid <- !is.na(tas + dewp + wind + radiation + Pair) & !is.na(zenith)
  input_status <- rep("attempted", n)
  input_status[is.na(tas) | is.na(dewp) | is.na(wind) | is.na(radiation) | is.na(Pair)] <-
    "missing_input"
  input_status[input_status == "attempted" & is.na(zenith)] <- "missing_date"

  if (controls$noNAs && controls$swap) {
    tas_tmp <- pmax(tas, dewp)
    dewp <- pmin(tas, dewp)
    tas <- tas_tmp
  } else if (controls$noNAs) {
    dewp[(dewp - tas) > controls$dewpoint_tolerance] <-
      tas[(dewp - tas) > controls$dewpoint_tolerance]
  } else {
    input_valid <- input_valid & tas >= dewp
    input_status[input_status == "attempted" & !is.na(tas) & !is.na(dewp) &
      dewp > tas] <- "invalid_dewpoint"
  }
  relh <- dewp2hurs(tas, dewp)
  valid_idx <- which(input_valid)
  Tg <- rep(NA_real_, n)
  Tnwb <- rep(NA_real_, n)
  Tg.batch <- NULL
  Tnwb.batch <- NULL
  if (length(valid_idx)) {
    chunk_controls <- controls
    chunk_controls$prop_direct <- chunk$direct_fraction[valid_idx]
    solved <- solve_liljegren_batch_chunk(list(
      tas = tas[valid_idx], dewp = dewp[valid_idx], relh = relh[valid_idx],
      Pair = Pair[valid_idx], wind = wind[valid_idx], radiation = radiation[valid_idx],
      zenith = zenith[valid_idx]
    ), chunk_controls)
    Tg.batch <- solved$Tg
    Tnwb.batch <- solved$Tnwb
    Tg[valid_idx] <- Tg.batch
    Tnwb[valid_idx] <- Tnwb.batch
  }
  list(
    n = n, data = ifelse(is.na(Tg) | is.na(Tnwb), NA_real_,
      0.7 * Tnwb + 0.2 * Tg + 0.1 * tas), Tg = Tg, Tnwb = Tnwb,
    input_valid = input_valid,
    input_status = input_status, solar_geometry_mismatch = solar_geometry_mismatch,
    valid_idx = valid_idx, Tg.batch = Tg.batch, Tnwb.batch = Tnwb.batch
  )
}

liljegren_failure_count_names <- c(
  "unbracketed", "non_finite", "residual_validation"
)

summarize_liljegren_chunk_failures <- function(result) {
  empty_counts <- stats::setNames(integer(length(liljegren_failure_count_names)),
    liljegren_failure_count_names)
  summarize_component <- function(batch_result) {
    if (is.null(batch_result)) return(empty_counts)
    converged <- attr(batch_result, "converged")
    reasons <- attr(batch_result, "failure_reason")
    if (length(converged) != length(batch_result) ||
        length(reasons) != length(batch_result)) {
      stop("batch solver result has malformed failure diagnostics")
    }
    stats::setNames(as.integer(table(factor(reasons[!converged],
      levels = liljegren_failure_count_names))), liljegren_failure_count_names)
  }

  tg_converged <- if (is.null(result$Tg.batch)) logical() else
    attr(result$Tg.batch, "converged")
  tnwb_converged <- if (is.null(result$Tnwb.batch)) logical() else
    attr(result$Tnwb.batch, "converged")
  if (length(tg_converged) != length(tnwb_converged))
    stop("batch solver chunk components have inconsistent lengths")

  list(
    attempted_rows = length(result$valid_idx),
    failed_rows = sum(!tg_converged | !tnwb_converged),
    Tg = summarize_component(result$Tg.batch),
    Tnwb = summarize_component(result$Tnwb.batch)
  )
}

compact_liljegren_chunk_result <- function(result) {
  list(
    n = result$n,
    data = result$data,
    Tg = result$Tg,
    Tnwb = result$Tnwb,
    failure_summary = summarize_liljegren_chunk_failures(result)
  )
}

combine_liljegren_failure_summaries <- function(chunk_results) {
  summaries <- lapply(chunk_results, `[[`, "failure_summary")
  if (!length(summaries) || any(vapply(summaries, is.null, logical(1))))
    stop("parallel chunk failure summaries are required")
  count_fields <- c("Tg", "Tnwb")
  for (summary in summaries) {
    if (!identical(sort(names(summary)),
      sort(c("attempted_rows", "failed_rows", count_fields)))) {
      stop("parallel chunk failure summary is malformed")
    }
    if (!all(vapply(summary[c("attempted_rows", "failed_rows")],
      function(value) length(value) == 1L && is.finite(value) && value >= 0,
      logical(1)))) {
      stop("parallel chunk failure counts are malformed")
    }
    for (field in count_fields) {
      counts <- summary[[field]]
      if (!identical(names(counts), liljegren_failure_count_names) ||
          length(counts) != length(liljegren_failure_count_names) ||
          any(!is.finite(counts) | counts < 0)) {
        stop("parallel chunk component failure counts are malformed")
      }
    }
  }
  list(
    attempted_rows = sum(vapply(summaries, `[[`, numeric(1), "attempted_rows")),
    failed_rows = sum(vapply(summaries, `[[`, numeric(1), "failed_rows")),
    Tg = Reduce(`+`, lapply(summaries, `[[`, "Tg")),
    Tnwb = Reduce(`+`, lapply(summaries, `[[`, "Tnwb"))
  )
}

combine_parallel_chunk_field <- function(chunk_results, field) {
  values <- lapply(chunk_results, `[[`, field)
  expected_lengths <- vapply(chunk_results, `[[`, integer(1), "n")
  if (!all(vapply(values, length, integer(1)) == expected_lengths))
    stop("parallel chunk field has an inconsistent length: ", field)
  unlist(values, use.names = FALSE)
}

solve_liljegren_parallel_worker <- function(chunk, controls, diagnostics) {
  chunk$zenith <- calculate_liljegren_zenith(
    chunk$dates, chunk$lon, chunk$lat, hour = chunk$hour
  )
  result <- solve_liljegren_batch_raw_chunk(chunk, controls)
  if (diagnostics) result else compact_liljegren_chunk_result(result)
}

capture_foreach_backend <- function() {
  globals <- utils::getFromNamespace(".foreachGlobals", "foreach")
  names <- c("fun", "data", "info")
  present <- vapply(names, exists, logical(1), envir = globals, inherits = FALSE)
  list(
    globals = globals,
    present = present,
    values = stats::setNames(lapply(names[present], get, envir = globals,
      inherits = FALSE), names[present])
  )
}

restore_foreach_backend <- function(backend) {
  names <- names(backend$present)
  for (name in names) {
    if (backend$present[[name]]) {
      assign(name, backend$values[[name]], envir = backend$globals)
    } else if (exists(name, envir = backend$globals, inherits = FALSE)) {
      rm(list = name, envir = backend$globals)
    }
  }
}

solve_liljegren_parallel <- function(tas, dewp, wind, radiation, dates, lon, lat,
                                     hour, pressure, direct_fraction, workers,
                                     controls, diagnostics) {
  n <- length(tas)
  effective_workers <- min(workers, n)
  if (effective_workers < 1L)
    stop("parallel solver requires at least one input row")
  indices <- split_liljegren_chunks(n, effective_workers)
  chunks <- lapply(indices, function(index) list(
    tas = tas[index], dewp = dewp[index], wind = wind[index],
    radiation = radiation[index],
    pressure = if (length(pressure) == 1L) pressure else pressure[index],
    direct_fraction = direct_fraction[index],
    dates = dates[index], lon = lon[index], lat = lat[index], hour = hour
  ))
  backend <- capture_foreach_backend()
  on.exit(restore_foreach_backend(backend), add = TRUE)
  cluster <- parallel::makePSOCKcluster(effective_workers)
  on.exit(parallel::stopCluster(cluster), add = TRUE)
  doParallel::registerDoParallel(cluster)
  chunk <- NULL
  chunk_results <- foreach::`%dopar%`(
    foreach::foreach(chunk = chunks, .packages = "HeatStressR", .inorder = TRUE),
    utils::getFromNamespace("solve_liljegren_parallel_worker", "HeatStressR")(
      chunk, controls, diagnostics
    )
  )
  if (!diagnostics) {
    return(list(
      data = combine_parallel_chunk_field(chunk_results, "data"),
      Tg = combine_parallel_chunk_field(chunk_results, "Tg"),
      Tnwb = combine_parallel_chunk_field(chunk_results, "Tnwb"),
      failure_summary = combine_liljegren_failure_summaries(chunk_results),
      workers = effective_workers
    ))
  }
  valid_idx <- as.integer(unlist(Map(function(result, index) {
    index[result$valid_idx]
  }, chunk_results, indices), use.names = FALSE))
  tg_chunks <- Filter(Negate(is.null), lapply(chunk_results, `[[`, "Tg.batch"))
  tnwb_chunks <- Filter(Negate(is.null), lapply(chunk_results, `[[`, "Tnwb.batch"))
  if (length(tg_chunks) != length(tnwb_chunks))
    stop("parallel solver chunks are inconsistent")
  list(
    data = combine_parallel_chunk_field(chunk_results, "data"),
    Tg = combine_parallel_chunk_field(chunk_results, "Tg"),
    Tnwb = combine_parallel_chunk_field(chunk_results, "Tnwb"),
    input_valid = combine_parallel_chunk_field(chunk_results, "input_valid"),
    input_status = combine_parallel_chunk_field(chunk_results, "input_status"),
    solar_geometry_mismatch = combine_parallel_chunk_field(chunk_results,
      "solar_geometry_mismatch"),
    valid_idx = valid_idx,
    Tg.batch = if (length(tg_chunks)) combine_batch_solver_results(tg_chunks) else numeric(),
    Tnwb.batch = if (length(tnwb_chunks)) combine_batch_solver_results(tnwb_chunks) else numeric(),
    workers = effective_workers
  )
}
