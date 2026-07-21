valid_solver_result <- function(value, residual, tolerance) {
  is.finite(value) & is.finite(residual) & abs(residual) <= tolerance
}
