WBGT_DIAGNOSTIC_FIELDS <- c(
  "batch_iterations", "batch_evaluations", "bracket_evaluations",
  "fallback_evaluations", "total_evaluations", "used_fallback",
  "batch_converged", "batch_valid", "fallback_converged", "converged", "evaluations",
  "batch_residual", "final_residual", "failure_reason", "fallback_reason",
  "initial_lower", "initial_upper", "lower", "upper", "final_lower", "final_upper", "lower_residual",
  "upper_residual", "candidate_root", "root_tolerance", "residual_tolerance"
)

expand_solver_diagnostics <- function(result, valid_idx, n) {
  attrs <- attributes(result)
  if (length(result) != length(valid_idx))
    stop("result length must match valid_idx length")
  if (anyDuplicated(valid_idx) || any(valid_idx < 1L | valid_idx > n))
    stop("valid_idx must contain unique positions within n")
  if (length(valid_idx)) {
    missing <- setdiff(WBGT_DIAGNOSTIC_FIELDS, names(attrs))
    unexpected <- setdiff(names(attrs), c(WBGT_DIAGNOSTIC_FIELDS,
      "fallback_count", "iterations", "residual"))
    if (length(missing))
      stop("result is missing required diagnostic attributes: ", paste(missing, collapse = ", "))
    if (length(unexpected))
      stop("result has unexpected diagnostic attributes: ", paste(unexpected, collapse = ", "))
    malformed <- vapply(WBGT_DIAGNOSTIC_FIELDS,
      function(field) length(attrs[[field]]) != length(valid_idx), logical(1))
    if (any(malformed))
      stop("diagnostic attributes must match valid_idx length: ",
        paste(names(malformed)[malformed], collapse = ", "))
  }
  integer_fields <- c("batch_iterations", "batch_evaluations",
    "bracket_evaluations", "fallback_evaluations", "total_evaluations", "evaluations")
  logical_fields <- c("used_fallback", "batch_converged", "batch_valid",
    "fallback_converged", "converged")
  numeric_fields <- c("batch_residual", "final_residual", "initial_lower",
    "initial_upper", "lower", "upper", "final_lower", "final_upper", "lower_residual", "upper_residual",
    "candidate_root", "root_tolerance", "residual_tolerance")
  expanded <- vector("list", length(WBGT_DIAGNOSTIC_FIELDS))
  names(expanded) <- WBGT_DIAGNOSTIC_FIELDS
  for (field in WBGT_DIAGNOSTIC_FIELDS) {
    value <- attrs[[field]]
    if (field %in% integer_fields) {
      target <- rep(NA_integer_, n)
    } else if (field %in% logical_fields) {
      target <- rep(NA, n)
    } else if (field %in% numeric_fields) {
      target <- rep(NA_real_, n)
    } else {
      target <- rep("not_attempted", n)
    }
    if (length(valid_idx)) target[valid_idx] <- value
    expanded[[field]] <- target
  }
  expanded
}

scalar_solver_diagnostics <- function(solutions, valid_idx, n) {
  empty <- function(mode) switch(mode, integer = rep(NA_integer_, n),
    logical = rep(NA, n), numeric = rep(NA_real_, n),
    character = rep("not_attempted", n))
  fields <- list(
    converged = empty("logical"), evaluations = empty("integer"),
    final_residual = empty("numeric"), failure_reason = empty("character"),
    used_fallback = rep(FALSE, n), initial_lower = empty("numeric"),
    initial_upper = empty("numeric"), final_lower = empty("numeric"),
    final_upper = empty("numeric"), lower_residual = empty("numeric"),
    upper_residual = empty("numeric"), candidate_root = empty("numeric"),
    root_tolerance = empty("numeric"), residual_tolerance = empty("numeric")
  )
  if (!length(valid_idx)) return(fields)
  extract <- function(name, mode) vapply(solutions, `[[`, mode, name)
  fields$converged[valid_idx] <- extract("converged", logical(1))
  fields$evaluations[valid_idx] <- extract("evaluations", integer(1))
  fields$final_residual[valid_idx] <- extract("residual", numeric(1))
  fields$failure_reason[valid_idx] <- extract("failure_reason", character(1))
  for (name in c("initial_lower", "initial_upper", "final_lower", "final_upper",
                 "lower_residual", "upper_residual", "candidate_root",
                 "root_tolerance", "residual_tolerance")) {
    fields[[name]][valid_idx] <- extract(name, numeric(1))
  }
  fields
}
