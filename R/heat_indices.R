#' Calculate all heat indices supported by supplied observations
#'
#' Uses the method registry to select and dispatch methods, including numerical
#' Romps, Lu, Bernard and Liljegren calculations. Explicit indices are recommended
#' for stable column sets and predictable workloads.
#'
#' @inheritParams heat-stress-indices
#' @param hurs Optional RH in percent; required by humidity-based methods.
#' @param wind Deprecated alias for wind_10m.
#' @param dewp Optional dew point in C for Bernard and Liljegren.
#' @param indices Canonical method names or deprecated aliases. NULL selects
#'   all methods whose declared observation inputs were supplied, in registry
#'   order. Explicit selection retains requested order and column labels.
#' @param wind_10m,wind_2m Wind in m/s at the indicated height. One is never
#'   substituted for the other.
#' @param radiation,time,lon,lat Optional Liljegren inputs; see [wbgt_liljegren()].
#' @param liljegren_options Named list containing direct_fraction,
#'   dewpoint_policy, workers, or control; see [wbgt_liljegren()].
#' @return A data frame by default. With diagnostics, list(values, components,
#'   diagnostics), where components and diagnostics are named lists by requested
#'   index. Validation/forcing warnings are summarized once per call.
#' @details No absent meteorological inputs are inferred. pressure defaults to
#'   1010 hPa, so Romps is selected when tas and hurs are supplied. An all-NA
#'   supplied input still satisfies availability, with NA rows in the result.
#'   All default column names are canonical. Humidity phase references differ
#'   between published methods below freezing; see [heat_methods()].
#' @eval paste0("@details Available methods:\n", .method_catalog_rd())
#' @export
#' @examples
#' heat_indices(c(25, 30), c(60, 70), indices = c("humidex", "heat_index_lu"))
#' heat_indices(30, 70, wind_10m = 2)
heat_indices <- function(tas, hurs = NULL, wind = NULL, dewp = NULL, indices = NULL,
                         wind_10m = NULL, wind_2m = NULL, pressure = 1010,
                         radiation = NULL, time = NULL, lon = NULL, lat = NULL,
                         diagnostics = FALSE, liljegren_options = list()) {
  .logical_control(diagnostics, "diagnostics")
  # DEPRECATED(v4): remove wind formal and this one compatibility hook.
  wind_10m <- .legacy_bulk_wind(wind, wind_10m)
  inputs <- list(tas = tas, hurs = hurs, dewp = dewp, wind_10m = wind_10m,
    wind_2m = wind_2m, pressure = pressure, radiation = radiation, time = time,
    lon = lon, lat = lat)
  inputs <- inputs[!vapply(inputs, is.null, logical(1))]
  if (is.null(indices)) {
    indices <- names(.method_registry)[vapply(.method_registry,
      function(m) all(m$inputs %in% names(inputs)), logical(1))]
  }
  .assert(is.character(indices) && length(indices) > 0L && !anyNA(indices),
    "'indices' must be unique supported index names; no methods match the supplied inputs")
  resolved <- vapply(indices, function(name) {
    if (name %in% names(.method_registry)) return(name)
    found <- names(.method_registry)[vapply(.method_registry,
      function(m) name %in% m$aliases, logical(1))]
    .assert(length(found) == 1L, "'indices' must be unique supported index names")
    # DEPRECATED(v4): remove alias resolution and this warning with registry aliases.
    .warn_deprecation(paste0("indices=", name), found)
    found
  }, character(1))
  .assert(!anyDuplicated(resolved), "'indices' must be unique supported index names")
  needed <- unique(unlist(lapply(.method_registry[resolved], `[[`, "inputs")))
  missing <- setdiff(needed, names(inputs))
  .assert(!length(missing), paste0("Missing required inputs: ", paste(missing, collapse = ", ")))
  # Align once so every method sees the same number of observation rows.
  inputs <- .align_inputs(inputs)
  options <- list()
  if ("wbgt_liljegren" %in% resolved) {
    .assert(is.list(liljegren_options) && (length(liljegren_options) == 0L ||
      (!is.null(names(liljegren_options)) && !anyNA(names(liljegren_options)) &&
       !anyDuplicated(names(liljegren_options)) && all(names(liljegren_options) %in%
        c("direct_fraction", "dewpoint_policy", "workers", "control")))),
      "'liljegren_options' must be a named list of supported options")
    defaults <- list(direct_fraction = 0.8, dewpoint_policy = "cap", workers = 1L, control = list())
    defaults[names(liljegren_options)] <- liljegren_options
    options <- list(control = .liljegren_controls(defaults$control),
      workers = validate_workers(defaults$workers), engine = "batch", diagnostics = diagnostics,
      dewpoint_policy = match.arg(defaults$dewpoint_policy, c("cap", "na", "error")))
    inputs$direct_fraction <- defaults$direct_fraction
    inputs <- .align_inputs(inputs)
  }
  groups <- new.env(parent = emptyenv())
  results <- vector("list", length(indices))
  names(results) <- indices
  warnings <- character()
  for (i in seq_along(indices)) {
    method <- resolved[i]
    required <- .method_registry[[method]]$inputs
    if (method == "wbgt_liljegren") required <- c(required, "direct_fraction")
    key <- paste(required, collapse = ":")
    if (!exists(key, groups, inherits = FALSE)) {
      assign(key, list(prepared = .prepare_inputs(inputs[required]),
        cache = new.env(parent = emptyenv())), groups)
    }
    group <- get(key, groups, inherits = FALSE)
    method_options <- if (method == "wbgt_liljegren") options else list()
    results[[i]] <- withCallingHandlers(
      .evaluate_method(method, inputs[required], diagnostics, method_options,
        group$cache, group$prepared),
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      })
  }
  if (length(warnings)) warning(paste(c("heat_indices:", unique(warnings)), collapse = "\n"), call. = FALSE)
  if (!diagnostics) return(as.data.frame(results, optional = TRUE))
  list(values = as.data.frame(lapply(results, `[[`, "values"), optional = TRUE),
    components = lapply(results, `[[`, "components"),
    diagnostics = lapply(results, `[[`, "diagnostics"))
}
