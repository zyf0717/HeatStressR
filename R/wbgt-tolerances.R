validate_tolerance <- function(value, name, maximum = NULL) {
  .assert(
    is.numeric(value) && length(value) == 1L && is.finite(value) && value > 0,
    msg = sprintf("'%s' must be one finite positive number", name)
  )
  if (!is.null(maximum)) {
    .assert(value <= maximum,
      msg = sprintf("'%s' must not exceed %g", name, maximum))
  }
  invisible(value)
}
