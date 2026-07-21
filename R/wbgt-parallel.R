max_liljegren_workers <- function() {
  detected <- parallel::detectCores(logical = TRUE)
  if (length(detected) != 1L || is.na(detected) || !is.finite(detected) || detected < 1L)
    return(1L)
  as.integer(detected)
}

validate_workers <- function(workers) {
  if (!is.numeric(workers) || length(workers) != 1L || is.na(workers) ||
      !is.finite(workers) || workers != floor(workers)) {
    stop("'workers' must be one finite integer")
  }
  if (workers < 1L)
    stop("'workers' must be at least 1")

  maximum <- max_liljegren_workers()
  if (workers > maximum)
    stop("'workers' must not exceed the detected logical CPU count (", maximum, ")")
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
                                  workers, min_wind_speed, tolerance, root_tolerance,
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

  if (workers == 1L || !n) {
    result <- solve_liljegren_batch_chunk(payload, controls)
    return(c(result, list(workers = workers)))
  }

  indices <- split_liljegren_chunks(n, workers)
  chunks <- lapply(indices, function(index) lapply(payload, `[`, index))
  cluster <- parallel::makePSOCKcluster(workers)
  on.exit(parallel::stopCluster(cluster), add = TRUE)
  parallel::clusterCall(cluster, function() {
    loadNamespace("HeatStressR")
    NULL
  })
  worker <- function(chunk, controls) {
    utils::getFromNamespace("solve_liljegren_batch_chunk", "HeatStressR")(chunk, controls)
  }
  chunk_results <- parallel::parLapply(cluster, chunks, worker, controls = controls)
  list(
    Tg = combine_batch_solver_results(lapply(chunk_results, `[[`, "Tg")),
    Tnwb = combine_batch_solver_results(lapply(chunk_results, `[[`, "Tnwb")),
    workers = workers
  )
}
