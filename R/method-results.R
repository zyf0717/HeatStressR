.modern_result <- function(method, x) {
  n <- length(x$tas)
  values <- rep(NA_real_, n)
  failure <- rep("not_attempted", n)
  valid <- which(is.finite(x$tas) & is.finite(x$hurs))
  calculate <- function(i) {
    if (method == "wetbulb") {
      heatindex::wetbulb(x$pressure[i] * 100, x$tas[i] + 273.15,
        x$hurs[i] / 100, psychrometric = FALSE, icebulb = FALSE, verbose = FALSE) - 273.15
    } else heatindex::heatindex(x$tas[i] + 273.15, x$hurs[i] / 100) - 273.15
  }
  if (length(valid)) {
    # Keep the fast vector call; isolate rows only if upstream throws an error.
    batch <- tryCatch(calculate(valid), error = function(e) NULL)
    if (is.null(batch)) {
      for (i in valid) {
        value <- tryCatch(calculate(i), error = function(e) NA_real_)
        values[i] <- value
      }
    } else values[valid] <- batch
    failure[valid] <- ifelse(is.finite(values[valid]), "none", "upstream_failure")
  }
  list(values = values, solver = list(failure_reason = failure,
    dependency = "heatindex", dependency_version = as.character(utils::packageVersion("heatindex"))))
}

.bernard_result <- function(x, options) {
  tolerance <- if (is.null(options$tolerance)) 1e-4 else options$tolerance
  validate_tolerance(tolerance, "tolerance")
  ed <- .saturation_vapour_pressure(x$dewp, "bernard")
  solved <- bernard_bisection(x$tas, x$dewp, ed, tolerance)
  list(values = 0.67 * solved$root + 0.33 * x$tas,
    components = list(tpwb = solved$root), solver = list(converged = solved$converged))
}

.liljegren_controls <- function(control) {
  defaults <- list(root_tolerance = 1e-6, residual_tolerance = 1e-4,
    surface_albedo = 0.45, globe_diameter = 0.0508, min_wind_speed = 0.13)
  .assert(is.list(control) && (length(control) == 0L ||
    (!is.null(names(control)) && !anyNA(names(control)) && !anyDuplicated(names(control)) &&
      all(names(control) %in% names(defaults)))), "'control' must be a named list of supported Liljegren controls")
  defaults[names(control)] <- control
  validate_tolerance(defaults$root_tolerance, "root_tolerance")
  validate_tolerance(defaults$residual_tolerance, "residual_tolerance", maximum = 0.01)
  .assert(is.numeric(defaults$surface_albedo) && length(defaults$surface_albedo) == 1L &&
    is.finite(defaults$surface_albedo) && defaults$surface_albedo >= 0 && defaults$surface_albedo <= 1,
    "'surface_albedo' must be one finite value between 0 and 1")
  .assert(is.numeric(defaults$globe_diameter) && length(defaults$globe_diameter) == 1L &&
    is.finite(defaults$globe_diameter) && defaults$globe_diameter > 0,
    "'globe_diameter' must be one positive finite value")
  .assert(is.numeric(defaults$min_wind_speed) && length(defaults$min_wind_speed) == 1L &&
    is.finite(defaults$min_wind_speed) && defaults$min_wind_speed >= 0,
    "'min_wind_speed' must be one non-negative finite value")
  defaults
}

.liljegren_result <- function(x, options) {
  if (!length(x$tas)) {
    return(list(values = numeric(), components = list(tnwb = numeric(), tg = numeric()),
      solver = list(engine = options$engine, workers = 0L, requested_workers = options$workers)))
  }
  raw <- suppressWarnings(.liljegren_core(x$tas, x$dewp, x$wind_2m, x$radiation,
    x$time, x$lon, x$lat, x$pressure, x$direct_fraction, options$control,
    options$workers, options$engine, options$diagnostics))
  list(values = raw$data, components = list(tnwb = raw$Tnwb, tg = raw$Tg), solver = raw$diagnostics)
}

.evaluate_method <- function(method, inputs, diagnostics = FALSE, options = list(),
                             cache = NULL, prepared = NULL, warn = TRUE, return_components = FALSE) {
  .logical_control(diagnostics, "diagnostics")
  m <- .method_registry[[method]]
  if (is.null(prepared)) prepared <- .prepare_inputs(inputs)
  if ("dewp" %in% names(prepared$inputs)) {
    policy <- if (is.null(options$dewpoint_policy)) "cap" else options$dewpoint_policy
    prepared <- .apply_dewpoint_policy(prepared, policy)
  } else prepared$adjusted <- rep(FALSE, prepared$n)
  x <- prepared$inputs
  domain <- rep("unknown", prepared$n)
  if (!is.null(m$domain_check)) domain <- m$domain_check(x)
  domain[!prepared$valid] <- "not_evaluated"
  result <- suppressWarnings(m$kernel(x, cache, options))
  values <- as.numeric(result$values)
  failed <- prepared$valid & !is.finite(values)
  values[!is.finite(values)] <- NA_real_
  if (warn) .warn_method_rows(method, prepared$status, domain, prepared$adjusted, failed)
  if (!diagnostics) {
    if (return_components) return(list(values = values, components = result$components))
    return(values)
  }
  rows <- data.frame(input_status = prepared$status, input_reason = prepared$reason,
    domain_status = domain, adjusted = prepared$adjusted,
    converged = ifelse(prepared$valid, !failed, NA),
    failure_reason = ifelse(!prepared$valid, "not_attempted", ifelse(failed, "solver_failure", "none")),
    stringsAsFactors = FALSE)
  solver <- result$solver
  if (method == "wbgt_liljegren" && prepared$n > 0L) {
    solver$attempted <- prepared$valid
    solver$input_status <- ifelse(prepared$status == "valid", "attempted", prepared$status)
    solver$dewpoint_adjusted <- prepared$adjusted
  }
  list(values = values, components = if (is.null(result$components)) list() else result$components,
    diagnostics = list(rows = rows, solver = solver,
      metadata = list(method = method, units = m$units, reference = m$reference,
        package_version = as.character(utils::packageVersion("HeatStressR")),
        humidity_reference = m$humidity,
        heatindex_version = if (method %in% c("wet_bulb_romps", "heat_index_lu"))
          as.character(utils::packageVersion("heatindex")) else NULL)))
}
