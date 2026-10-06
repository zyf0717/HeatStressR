.input_units <- c(tas = "degC", dewp = "degC", hurs = "%",
  wind = "m/s", wind_10m = "m/s", wind_2m = "m/s", radiation = "W/m2",
  pressure = "hPa", direct_fraction = "fraction", time = "instant",
  lon = "degrees east", lat = "degrees north")

# Base assertions for scalar numerical controls (also used by solver kernels).
.assert <- function(condition, msg) {
  if (!isTRUE(condition)) stop(msg, call. = FALSE)
  invisible(TRUE)
}

.logical_control <- function(value, name) {
  .assert(is.logical(value) && length(value) == 1L && !is.na(value),
    paste0("'", name, "' must be a single logical value"))
}

# Only scalars expand. NULL means absent, whereas numeric(0) means no rows.
.align_inputs <- function(inputs) {
  .assert(all(vapply(inputs, function(x) is.null(dim(x)), logical(1))),
    "Input observations must be vectors, not matrices or arrays")
  sizes <- lengths(inputs)
  if (any(sizes == 0L)) {
    .assert(all(sizes %in% c(0L, 1L)), "Input vectors do not have the same length")
    n <- 0L
  } else {
    n <- max(sizes)
    .assert(all(sizes %in% c(1L, n)), "Input vectors do not have the same length")
  }
  lapply(inputs, function(x) if (length(x) == n) x else rep(x, length.out = n))
}

.normalise_time <- function(time) {
  if (inherits(time, "POSIXt")) {
    # First preserve the instant in the input's own zone. Passing tz="UTC"
    # directly to as.POSIXct.POSIXlt would reinterpret its wall-clock fields.
    instant <- as.POSIXct(time)
    attr(instant, "tzone") <- "UTC"
    return(instant)
  }
  .assert(is.character(time), "'time' must be POSIX timestamps or offset-bearing ISO 8601 strings")
  parse_iso8601_datetime(time)
}

# Validation is row-wise for observations and call-wise for type/shape mistakes.
.prepare_inputs <- function(inputs) {
  for (name in names(inputs)) {
    x <- inputs[[name]]
    if (name == "time") {
      .assert((inherits(x, "POSIXt") || is.character(x)) && is.null(dim(x)),
        "'time' must be POSIX timestamps or offset-bearing ISO 8601 strings")
    } else {
      .assert(is.numeric(x) && is.null(dim(x)), paste0("'", name, "' must be a numeric vector"))
    }
  }
  inputs <- .align_inputs(inputs)
  n <- length(inputs[[1L]])
  status <- rep("valid", n)
  reason <- rep("", n)
  for (name in names(inputs)) {
    x <- inputs[[name]]
    missing <- is.na(x) & !is.nan(if (is.character(x)) rep(0, n) else as.numeric(x))
    if (name == "time") {
      x <- .normalise_time(x)
      bad <- !missing & !is.finite(as.numeric(x))
    } else {
      bad <- !missing & !is.finite(x)
      bounds <- switch(name,
        tas = x <= -273.15, dewp = x <= -273.15,
        hurs = x < 0 | x > 100,
        wind = x < 0, wind_10m = x < 0, wind_2m = x < 0, radiation = x < 0, pressure = x <= 0,
        direct_fraction = x < 0 | x > 1,
        lon = x < -180 | x > 180, lat = x < -90 | x > 90,
        zenith = x < 0 | x > pi,
        rep(FALSE, n))
      bad <- bad | (!is.na(bounds) & bounds)
    }
    first_missing <- missing & status == "valid"
    status[first_missing] <- "missing_input"
    reason[first_missing] <- name
    first_bad <- bad & status != "invalid_input"
    status[first_bad] <- "invalid_input"
    reason[first_bad] <- name
    inputs[[name]] <- x
  }
  valid <- status == "valid"
  if (any(!valid)) for (name in names(inputs)) inputs[[name]][!valid] <- NA
  list(inputs = inputs, status = status, reason = reason, valid = valid, n = n)
}

.apply_dewpoint_policy <- function(prepared, policy) {
  policy <- match.arg(policy, c("cap", "na", "error"))
  x <- prepared$inputs
  above <- which(prepared$valid & x$dewp > x$tas)
  prepared$adjusted <- rep(FALSE, prepared$n)
  if (length(above)) {
    if (policy == "error") stop("'dewp' exceeds 'tas' at rows: ", paste(above, collapse = ", "), call. = FALSE)
    if (policy == "cap") {
      prepared$inputs$dewp[above] <- x$tas[above]
      prepared$adjusted[above] <- TRUE
    } else {
      prepared$status[above] <- "invalid_dewpoint"
      prepared$reason[above] <- "dewp"
      prepared$valid[above] <- FALSE
      for (name in names(x)) prepared$inputs[[name]][above] <- NA
    }
  }
  prepared
}

.warn_method_rows <- function(method, status, domain, adjusted, failed) {
  counts <- c(invalid = sum(status %in% c("invalid_input", "invalid_dewpoint")),
    outside_domain = sum(domain == "outside"), adjusted = sum(adjusted),
    solver_failure = sum(failed))
  counts <- counts[counts > 0L]
  if (length(counts)) warning(paste0(method, ": ",
    paste(paste(names(counts), counts, sep = "="), collapse = ", "),
    ". Use diagnostics = TRUE for row-level details."), call. = FALSE)
}
