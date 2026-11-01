# Explicit, standalone wind-height preprocessing. These utilities are upstream
# of every heat-stress method; no kernel performs implicit height conversion.

#' Convert wind speed between measurement heights
#'
#' @description
#' Converts wind speed from one measurement height to another using an
#' explicit, caller-selected profile method. This is a preprocessing step:
#' convert observations to the height a heat-stress method requires (for
#' example 2 m for [wbgt_liljegren()] or 10 m for indices documented at
#' 10 m), then pass the converted value as that method's wind input.
#'
#' Two methods are provided:
#' \describe{
#'   \item{`method = "power"`}{Power-law profile,
#'     `u_to = u_from * (to_height_m / from_height_m)^exponent`.
#'     The exponent must be supplied explicitly; no default such as the
#'     1/7-power rule is assumed, because the appropriate exponent depends on
#'     surface roughness and stability.}
#'   \item{`method = "neutral_log"`}{Neutral logarithmic profile,
#'     `u_to = u_from * log((to_height_m - d) / z0) / log((from_height_m - d) / z0)`
#'     with surface roughness length `z0 = roughness_length_m` and zero-plane
#'     displacement height `d = displacement_height_m`. Requires
#'     `from_height_m > d + z0` and `to_height_m > d + z0`.}
#' }
#'
#' @param wind Wind speed in m/s at `from_height_m`. Zero is valid; negative
#'   values are invalid.
#' @param from_height_m Measurement height of `wind` in metres above the
#'   surface. Must be positive.
#' @param to_height_m Target height in metres above the surface. Must be
#'   positive. Default 2.
#' @param method Either `"power"` or `"neutral_log"`. No default; the
#'   conversion method is always an explicit analysis choice.
#' @param exponent Power-law exponent (dimensionless). Required, finite and
#'   non-`NA` for `method = "power"`; ignored otherwise.
#' @param roughness_length_m Surface roughness length `z0` in metres.
#'   Required and strictly positive for `method = "neutral_log"`; ignored
#'   otherwise.
#' @param displacement_height_m Zero-plane displacement height `d` in metres.
#'   Default 0 (open terrain). Used only by `method = "neutral_log"`.
#' @return Numeric wind speed in m/s at `to_height_m`. Scalars expand and
#'   equal-length vectors are processed row-wise; `numeric(0)` is preserved.
#'   `NA` inputs propagate. Rows that are physically invalid (negative wind,
#'   non-positive heights, non-finite exponent, non-positive roughness, or a
#'   height at or below `d + z0`) become `NA` with a summary warning.
#'   No minimum-wind clamp is applied; use method-specific controls such as
#'   [wbgt_liljegren()]`$min_wind_speed` for that, and do not apply both.
#' @details
#' Both profiles describe a horizontally homogeneous surface layer under
#' near-neutral stability. The power law is an empirical fit whose exponent
#' varies with terrain and stability; the log law assumes a neutral surface
#' layer and can fail outright inside and above urban canopies, where
#' extrapolating below `d + z0` is undefined. Conversion between heights
#' does not resolve exposure representativeness, terrain or building
#' effects, or time-averaging mismatches between source and target series.
#'
#' When `from_height_m` equals `to_height_m` the wind is returned unchanged,
#' subject to ordinary wind and height validation.
#'
#' Record the source height, method and parameters alongside converted
#' results for reproducibility. See Anderson et al. (2024) for a comparison
#' of wind-height conversions for global reanalyses.
#'
#' @references
#' Anderson, R., Paul, S., Coomes, D. A. and Emery, N. C. (2024).
#' "Vertical Wind Downscaling for Global Offshore Wind Speed Resource
#' Assessment." Journal of Applied Meteorology and Climatology.
#' \doi{10.1175/JAMC-D-24-0009.1}
#' @examples
#' # 10 m reanalysis wind to the 2 m height wbgt_liljegren() expects,
#' # using an explicit neutral log-law with open-terrain roughness.
#' wind_at_height(4, from_height_m = 10, method = "neutral_log",
#'                roughness_length_m = 0.1)
#'
#' # Power law with an explicit exponent, row-wise.
#' wind_at_height(c(3, 6), from_height_m = c(10, 10), to_height_m = 2,
#'                method = "power", exponent = 0.143)
#' @export
wind_at_height <- function(wind, from_height_m, to_height_m = 2, method,
                           exponent = NULL, roughness_length_m = NULL,
                           displacement_height_m = 0) {
  method <- match.arg(method, c("power", "neutral_log"))
  if (method == "power" && is.null(exponent)) {
    stop("'exponent' must be supplied explicitly for method = \"power\"",
      call. = FALSE)
  }
  if (method == "neutral_log" && is.null(roughness_length_m)) {
    stop("'roughness_length_m' must be supplied explicitly for method = ",
      "\"neutral_log\"", call. = FALSE)
  }
  controls <- switch(method,
    power = list(exponent = exponent),
    neutral_log = list(roughness_length_m = roughness_length_m,
      displacement_height_m = displacement_height_m))
  for (name in names(controls)) {
    x <- controls[[name]]
    .assert(is.numeric(x) && is.null(dim(x)) && length(x) > 0L,
      paste0("'", name, "' must be a numeric vector"))
  }

  prepared <- .prepare_inputs(list(wind = wind,
    from_height_m = from_height_m, to_height_m = to_height_m))
  status <- prepared$status
  reason <- prepared$reason
  valid <- prepared$valid
  n <- prepared$n
  wind_v <- prepared$inputs$wind
  from_v <- prepared$inputs$from_height_m
  to_v <- prepared$inputs$to_height_m

  for (name in names(controls)) {
    x <- as.numeric(controls[[name]])
    if (length(x) == 1L && n != 1L) x <- rep(x, length.out = n)
    .assert(length(x) == n, "Control vectors do not have the same length")
    controls[[name]] <- x
  }

  # Ordinary height validity: heights must be positive and finite.
  bad_height <- valid & (!is.finite(from_v) | !is.finite(to_v) |
    from_v <= 0 | to_v <= 0)
  mark_invalid <- function(rows, why) {
    rows <- rows & status != "invalid_input"
    status[rows] <<- "invalid_input"
    reason[rows] <<- why
    valid <<- valid & !rows
  }
  mark_invalid(bad_height, "height")

  # Equal-height rows return the input wind unchanged, exempt from
  # method-parameter row validity (but not from wind/height validity).
  same_height <- valid & is.finite(from_v) & is.finite(to_v) & from_v == to_v

  values <- rep(NA_real_, n)
  if (method == "power") {
    exponent_v <- controls$exponent
    mark_invalid(valid & !same_height & !is.finite(exponent_v), "exponent")
    rows <- valid
    values[rows] <- wind_v[rows] * (to_v[rows] / from_v[rows])^exponent_v[rows]
  } else {
    z0_v <- controls$roughness_length_m
    d_v <- controls$displacement_height_m
    admissible <- is.finite(z0_v) & (z0_v > 0) & is.finite(d_v) &
      (from_v - d_v > z0_v) & (to_v - d_v > z0_v)
    mark_invalid(valid & !same_height & !admissible, "roughness")
    rows <- valid
    values[rows] <- wind_v[rows] *
      log((to_v[rows] - d_v[rows]) / z0_v[rows]) /
      log((from_v[rows] - d_v[rows]) / z0_v[rows])
  }
  values[same_height] <- wind_v[same_height]

  failed <- valid & !is.finite(values)
  values[!valid | failed] <- NA_real_
  # Missing values stay silent in the v3 style; only invalid rows warn.
  counts <- c(invalid = sum(status == "invalid_input"),
    failed = sum(failed))
  counts <- counts[counts > 0L]
  if (length(counts)) {
    warning(paste0("wind_at_height: ",
      paste(names(counts), counts, sep = "="),
      ". Invalid rows are NA; see ?wind_at_height for validity rules."),
      call. = FALSE)
  }
  values
}
