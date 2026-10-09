bernard_psychrometric_residual <- function(Tpwb, tas, ed) {
  c4 <- 1556
  c5 <- 1.484
  c6 <- 1010

  saturation_pressure <- .saturation_vapour_pressure(Tpwb, "bernard")
  (c4 - c5 * Tpwb) * (ed - saturation_pressure) + c6 * (tas - Tpwb)
}

bernard_bisection <- function(tas, dewp, ed, tolerance,
                              max_iterations = 64L) {
  lower <- dewp
  upper <- tas
  lower_residual <- bernard_psychrometric_residual(lower, tas, ed)
  upper_residual <- bernard_psychrometric_residual(upper, tas, ed)
  bracketed <- is.finite(lower_residual) & is.finite(upper_residual) &
    (lower_residual == 0 | upper_residual == 0 |
      sign(lower_residual) != sign(upper_residual))
  root <- rep(NA_real_, length(tas))

  lower_root <- bracketed & lower_residual == 0
  upper_root <- bracketed & !lower_root & upper_residual == 0
  root[lower_root] <- lower[lower_root]
  root[upper_root] <- upper[upper_root]
  active <- bracketed & is.na(root) & (upper - lower > tolerance)

  for (iteration in seq_len(max_iterations)) {
    idx <- which(active)
    if (!length(idx)) break

    midpoint <- lower[idx] + (upper[idx] - lower[idx]) / 2
    midpoint_residual <- bernard_psychrometric_residual(
      midpoint, tas[idx], ed[idx]
    )
    finite <- is.finite(midpoint_residual)
    if (any(finite)) {
      update_idx <- idx[finite]
      same_as_lower <- sign(midpoint_residual[finite]) ==
        sign(lower_residual[update_idx])
      lower_idx <- update_idx[same_as_lower]
      upper_idx <- update_idx[!same_as_lower]
      lower[lower_idx] <- midpoint[finite][same_as_lower]
      lower_residual[lower_idx] <- midpoint_residual[finite][same_as_lower]
      upper[upper_idx] <- midpoint[finite][!same_as_lower]
      upper_residual[upper_idx] <- midpoint_residual[finite][!same_as_lower]

      exact_idx <- update_idx[midpoint_residual[finite] == 0]
      root[exact_idx] <- midpoint[finite][midpoint_residual[finite] == 0]
    }
    active[idx[!finite]] <- FALSE
    active[idx[finite]] <- is.na(root[idx[finite]]) &
      (upper[idx[finite]] - lower[idx[finite]] > tolerance)
  }

  converged <- bracketed & (is.finite(root) | (upper - lower <= tolerance))
  root[converged & is.na(root)] <- (lower[converged & is.na(root)] +
    upper[converged & is.na(root)]) / 2
  list(root = root, converged = converged)
}

