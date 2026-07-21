# Vectorized safeguarded root finder for independent monotone-decreasing
# residuals. It preserves a sign-changing bracket for every converged row.
vector_uniroot <- function(residual, lower, upper, lower_limit, upper_limit,
                           tolerance = 1e-4, max_iterations = 100L) {
  lengths <- vapply(list(upper, lower_limit, upper_limit), length, integer(1))
  n <- length(lower)
  if (!all(lengths == n))
    stop("lower, upper, and limits must have the same length")
  if (!is.numeric(tolerance) || length(tolerance) != 1L ||
      !is.finite(tolerance) || tolerance <= 0)
    stop("tolerance must be one finite positive number")
  if (!is.numeric(max_iterations) || length(max_iterations) != 1L ||
      !is.finite(max_iterations) || max_iterations < 1 ||
      max_iterations != as.integer(max_iterations))
    stop("max_iterations must be a positive integer")
  if (any(!is.finite(c(lower, upper, lower_limit, upper_limit))))
    stop("bracket endpoints and limits must be finite")
  if (any(lower > upper)) stop("lower must not exceed upper")
  if (any(lower_limit > lower)) stop("lower_limit must not exceed lower")
  if (any(upper_limit < upper)) stop("upper_limit must not be below upper")

  evaluations <- integer(n)
  evaluate <- function(x, idx) {
    value <- residual(x, idx)
    if (length(value) != length(idx))
      stop("residual must return one value per requested index")
    evaluations[idx] <<- evaluations[idx] + 1L
    value
  }
  is_bracketed <- function(f.lower, f.upper) {
    is.finite(f.lower) & is.finite(f.upper) &
      (f.lower == 0 | f.upper == 0 | sign(f.lower) != sign(f.upper))
  }
  f.lower <- evaluate(lower, seq_len(n))
  f.upper <- evaluate(upper, seq_len(n))
  initial.lower <- lower
  initial.upper <- upper
  initial.lower.residual <- f.lower
  initial.upper.residual <- f.upper
  reason <- rep("none", n)
  bracketed <- is_bracketed(f.lower, f.upper)

  # Expand only the side implied by a decreasing residual, avoiding an
  # unnecessary non-finite excursion on the opposite side.
  while (any(!bracketed & reason == "none")) {
    idx <- which(!bracketed & reason == "none")
    non_finite <- !is.finite(f.lower[idx]) | !is.finite(f.upper[idx])
    reason[idx[non_finite]] <- "non_finite"
    idx <- idx[!non_finite]
    if (!length(idx)) next
    width <- pmax(upper[idx] - lower[idx], 1)
    expand_upper <- f.lower[idx] > 0 & f.upper[idx] > 0 & upper[idx] < upper_limit[idx]
    expand_lower <- f.lower[idx] < 0 & f.upper[idx] < 0 & lower[idx] > lower_limit[idx]
    if (!any(expand_upper | expand_lower)) {
      reason[idx] <- "unbracketed"
      next
    }
    if (any(expand_upper)) {
      moved <- idx[expand_upper]
      upper[moved] <- pmin(upper[moved] + width[expand_upper], upper_limit[moved])
      f.upper[moved] <- evaluate(upper[moved], moved)
    }
    if (any(expand_lower)) {
      moved <- idx[expand_lower]
      lower[moved] <- pmax(lower[moved] - width[expand_lower], lower_limit[moved])
      f.lower[moved] <- evaluate(lower[moved], moved)
    }
    bracketed <- is_bracketed(f.lower, f.upper)
  }

  root <- rep(NA_real_, n)
  final.residual <- rep(NA_real_, n)
  iterations <- integer(n)
  converged <- rep(FALSE, n)
  # `tolerance` is root-location precision, not a residual-acceptance limit.
  # Exact endpoint roots can be returned immediately; all other candidates are
  # accepted only after their enclosing interval is sufficiently narrow.
  lower_root <- bracketed & f.lower == 0
  upper_root <- bracketed & !lower_root & f.upper == 0
  root[lower_root] <- lower[lower_root]
  final.residual[lower_root] <- f.lower[lower_root]
  root[upper_root] <- upper[upper_root]
  final.residual[upper_root] <- f.upper[upper_root]
  converged[lower_root | upper_root] <- TRUE
  active <- bracketed & !converged
  for (iteration in seq_len(as.integer(max_iterations))) {
    idx <- which(active)
    if (!length(idx)) break
    denominator <- f.upper[idx] - f.lower[idx]
    candidate <- upper[idx] - f.upper[idx] * (upper[idx] - lower[idx]) / denominator
    midpoint <- 0.5 * (lower[idx] + upper[idx])
    unsafe <- !is.finite(candidate) | candidate <= lower[idx] | candidate >= upper[idx]
    candidate[unsafe] <- midpoint[unsafe]
    f.candidate <- evaluate(candidate, idx)
    bad <- !is.finite(f.candidate)
    if (any(bad)) {
      retry_idx <- idx[bad]
      f.candidate[bad] <- evaluate(midpoint[bad], retry_idx)
      candidate[bad] <- midpoint[bad]
    }
    bad <- !is.finite(f.candidate)
    if (any(bad)) {
      failed <- idx[bad]
      reason[failed] <- "non_finite"
      active[failed] <- FALSE
    }
    usable <- !bad
    if (!any(usable)) next
    used_idx <- idx[usable]
    used_candidate <- candidate[usable]
    used_residual <- f.candidate[usable]
    same_as_lower <- sign(f.lower[used_idx]) == sign(used_residual) & f.lower[used_idx] != 0
    lower[used_idx[same_as_lower]] <- used_candidate[same_as_lower]
    f.lower[used_idx[same_as_lower]] <- used_residual[same_as_lower]
    upper[used_idx[!same_as_lower]] <- used_candidate[!same_as_lower]
    f.upper[used_idx[!same_as_lower]] <- used_residual[!same_as_lower]
    root[used_idx] <- used_candidate
    final.residual[used_idx] <- used_residual
    iterations[used_idx] <- iteration
    done <- used_residual == 0 | (upper[used_idx] - lower[used_idx]) <= tolerance
    converged[used_idx[done]] <- TRUE
    active[used_idx[done]] <- FALSE
  }
  reason[bracketed & !converged & reason == "none"] <- "max_iterations"
  list(root = root, converged = converged, iterations = iterations,
    evaluations = evaluations, residual = final.residual, lower = lower,
    upper = upper, lower_residual = f.lower, upper_residual = f.upper,
    initial_lower = initial.lower, initial_upper = initial.upper,
    initial_lower_residual = initial.lower.residual,
    initial_upper_residual = initial.upper.residual, failure_reason = reason)
}
