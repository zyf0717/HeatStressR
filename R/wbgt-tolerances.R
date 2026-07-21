validate_tolerance <- function(value, name, maximum = NULL) {
  assertthat::assert_that(
    is.numeric(value) && length(value) == 1L && is.finite(value) && value > 0,
    msg = sprintf("'%s' must be one finite positive number", name)
  )
  if (!is.null(maximum)) {
    assertthat::assert_that(value <= maximum,
      msg = sprintf("'%s' must not exceed %g", name, maximum))
  }
  invisible(value)
}
