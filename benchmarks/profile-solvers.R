#!/usr/bin/env Rscript

script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
candidate <- if (length(script_arg)) file.path(dirname(sub("^--file=", "", script_arg[1])), "..") else getwd()
root <- normalizePath(if (file.exists(file.path(candidate, "DESCRIPTION"))) candidate else getwd())
pkgload::load_all(root, quiet = TRUE)

profile_fTg <- function(tas, ...) {
  started <- proc.time()[["elapsed"]]
  value <- fTg_batch(tas = tas, ...)
  lower <- tas - 2
  upper <- tas + 100
  list(value = unname(value), evaluations = attr(value, "iterations"), objective = abs(attr(value, "residual")),
       lower = lower, upper = upper, boundary_distance = pmin(abs(value - lower), abs(value - upper)),
       elapsed = proc.time()[["elapsed"]] - started, fallback = attr(value, "fallback_count"))
}

profile_fTnwb <- function(tas, dewp, ...) {
  started <- proc.time()[["elapsed"]]
  value <- fTnwb_batch(tas = tas, dewp = dewp, ...)
  lower <- dewp - 1
  upper <- tas + 1
  list(value = unname(value), evaluations = attr(value, "iterations"), objective = abs(attr(value, "residual")),
       lower = lower, upper = upper, boundary_distance = pmin(abs(value - lower), abs(value - upper)),
       elapsed = proc.time()[["elapsed"]] - started, fallback = attr(value, "fallback_count"))
}
