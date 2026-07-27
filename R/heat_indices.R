#' Calculate multiple heat indices from shared observations.
#'
#' Calculates selected non-Liljegren heat indices while reusing validation and
#' vapour pressure calculations across the requested indices.
#'
#' @param tas vector of air temperature in degC.
#' @param hurs vector of relative humidity in \%.
#' @param wind optional vector of wind at 10m in m/s. Required by
#'   \code{apparentTemp} and \code{effectiveTemp}.
#' @param dewp optional vector of dew point temperature in degC. Required only
#'   when \code{wbgt.Bernard} is requested.
#' @param indices character vector of requested indices. \code{wbgt.Bernard}
#'   is available when \code{dewp} is supplied but is not selected by default.
#'
#' @return A data frame with one row per input observation and one column per
#'   requested index. The optional \code{wbgt.Bernard} column contains the WBGT
#'   value; call \code{wbgt.Bernard()} directly to obtain \code{Tpwb} too.
#' @export
heat_indices <- function(tas, hurs, wind = NULL, dewp = NULL,
                         indices = c("wbt", "swbgt", "apparentTemp",
                           "effectiveTemp", "humidex", "discomInd", "hi")) {
  available <- c("wbt", "swbgt", "apparentTemp", "effectiveTemp", "humidex",
    "discomInd", "hi", "wbgt.Bernard")
  assertthat::assert_that(is.character(indices) && length(indices) > 0L &&
      !anyNA(indices) && all(indices %in% available) && !anyDuplicated(indices),
    msg = "indices must be unique supported index names")
  .validate_tas_hurs(tas, hurs)

  needs_wind <- any(indices %in% c("apparentTemp", "effectiveTemp"))
  if (needs_wind) {
    assertthat::assert_that(!is.null(wind) && length(wind) == length(tas),
      msg = "Input vectors do not have the same length")
  }
  if ("wbgt.Bernard" %in% indices) {
    assertthat::assert_that(!is.null(dewp) && length(dewp) == length(tas),
      msg = "Input vectors do not have the same length")
  }

  needs_vapour_pressure <- any(indices %in% c("swbgt", "apparentTemp", "humidex"))
  vapour_pressure <- if (needs_vapour_pressure) .vapour_pressure_hpa(tas, hurs)
  result <- vector("list", length(indices))
  names(result) <- indices

  for (index in indices) {
    result[[index]] <- switch(index,
      wbt = .wbt_stull(tas, hurs),
      swbgt = 0.567 * tas + 0.216 * vapour_pressure + 3.38,
      apparentTemp = tas + 0.33 * vapour_pressure - 0.7 * wind - 4,
      effectiveTemp = 37 - (37 - tas) / (0.68 - 0.0014 * hurs +
        1 / (1.76 + 1.4 * (wind ^ 0.75))) - 0.29 * tas * (1 - 0.01 * hurs),
      humidex = tas + 5 / 9 * (vapour_pressure - 10),
      discomInd = tas - 0.55 * (1 - 0.01 * hurs) * (tas - 14.5),
      hi = .heat_index(tas, hurs),
      wbgt.Bernard = wbgt.Bernard(tas, dewp)$data
    )
  }
  as.data.frame(result, optional = TRUE)
}
