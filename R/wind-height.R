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
#'   Default 0 (open terrain). Must be non-negative; negative values have no
#'   physical meaning for a zero-plane displacement and mark the row invalid.
#'   Used only by `method = "neutral_log"`.
#' @return Numeric wind speed in m/s at `to_height_m`. Scalars expand and
#'   equal-length vectors are processed row-wise; `numeric(0)` is preserved.
#'   `NA` inputs propagate. Rows that are physically invalid (negative wind,
#'   non-positive heights, non-finite exponent, non-positive roughness,
#'   negative displacement height, or a height at or below `d + z0`) become
#'   `NA` with a summary warning.
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
#' results for reproducibility.
#'
#' @references
#' U.S. EPA (2000). "Meteorological Monitoring Guidance for Regulatory
#' Modeling Applications." EPA-454/R-99-005, section 6.2.5 (stability-class
#' wind-profile adjustment).
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
    # A zero-plane displacement height is the height the profile is shifted
    # to; negative values have no physical meaning for conventional
    # canopy/roughness applications and are rejected row-wise.
    mark_invalid(valid & !same_height & is.finite(d_v) & d_v < 0,
      "displacement")
    admissible <- is.finite(z0_v) & (z0_v > 0) & is.finite(d_v) & (d_v >= 0) &
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

# Original Liljegren v1.1 SRDT tables, transcribed verbatim from stab_srdt()
# and est_wind_speed() in the retained wbgt.c.original (EPA-454/R-99-005,
# 2000, section 6.2.5). Rows are wind-speed classes (day: i = 0..4 for
# < 2, 2-3, 3-5, 5-6, >= 6 m/s; night: i = 0..2 for < 2, 2-2.5, >= 2.5 m/s).
# Columns are 0-based as in C: day j = 0..3 for solar >= 925, >= 675,
# >= 175, < 175 W/m2; night j = 5 for delta_t < 0 and j = 6 for
# delta_t >= 0. Entries 0 and the sixth row are unreachable padding kept for
# table fidelity.
.srdt_lsrdt <- rbind(
  c(1, 1, 2, 4, 0, 5, 6, 0),
  c(1, 2, 3, 4, 0, 5, 6, 0),
  c(2, 2, 3, 4, 0, 4, 4, 0),
  c(3, 3, 4, 4, 0, 0, 0, 0),
  c(3, 4, 4, 4, 0, 0, 0, 0),
  c(0, 0, 0, 0, 0, 0, 0, 0))

# est_wind_speed() exponent tables, indexed by stability class 1..6.
.srdt_urban_exp <- c(0.15, 0.15, 0.20, 0.25, 0.30, 0.30)
.srdt_rural_exp <- c(0.07, 0.07, 0.10, 0.15, 0.35, 0.55)

# est_wind_speed() calm floor (MIN_SPEED) and reference height (REF_HEIGHT).
.srdt_min_speed <- 0.13
.srdt_ref_height_m <- 2

# 0/1 flag vectors accepted as logical or numeric 0/1; NA stays missing.
.srdt_flag <- function(x, name) {
  .assert(is.null(dim(x)) && (is.logical(x) || is.numeric(x)),
    paste0("'", name, "' must be a logical or 0/1 numeric vector"))
  if (is.numeric(x)) {
    .assert(all(is.na(x) | x %in% c(0, 1)),
      paste0("'", name, "' numeric values must be 0 or 1"))
    out <- rep(NA, length(x))
    known <- !is.na(x)
    out[known] <- x[known] == 1
    x <- out
  }
  x
}

# stab_srdt() port. Callers pass sanitized, row-valid daytime, speed, solar
# and delta_t; delta_t is only consulted for rows that need it.
.srdt_stability_class <- function(daytime, speed, solar, delta_t) {
  j <- ifelse(daytime,
    ifelse(solar >= 925, 1L, ifelse(solar >= 675, 2L,
      ifelse(solar >= 175, 3L, 4L))),
    ifelse(delta_t >= 0, 7L, 6L))
  i <- ifelse(daytime,
    ifelse(speed >= 6, 5L, ifelse(speed >= 5, 4L, ifelse(speed >= 3, 3L,
      ifelse(speed >= 2, 2L, 1L)))),
    ifelse(speed >= 2.5, 3L, ifelse(speed >= 2, 2L, 1L)))
  matrix(.srdt_lsrdt[cbind(i, j)], ncol = 1L)[, 1L] |> as.integer()
}

#' Estimate 2 m wind with the Liljegren SRDT stability-class method
#'
#' @description
#' Compatibility estimator reproducing the original Liljegren v1.1 SRDT
#' (Solar Radiation/Delta Temperature) stability-class lookup and 2 m
#' power-law estimate from the retained C implementation (EPA-454/R-99-005, 2000,
#' section 6.2.5). Use it when a reanalysis or tower wind must be reduced to
#' the 2 m height [wbgt_liljegren()] expects using exactly the original
#' stability logic. For any other height conversion, including 2 m targets
#' under neutral assumptions, use [wind_at_height()] instead; this function
#' is the only place the SRDT tables and the 0.13 m/s estimated-speed floor
#' apply.
#'
#' The stability class is computed from the wind speed at its ORIGINAL
#' measurement height, before conversion, exactly as the C program does.
#' Daytime classes use the wind thresholds 2/3/5/6 m/s and radiation
#' classes at 175/675/925 W/m2; nighttime classes use wind thresholds
#' 2/2.5 m/s and the sign of `delta_t_10m_2m_c`. Separate rural and urban
#' power-law exponent tables are applied, selected by the explicit `urban`
#' flag. The estimated speed is `wind * (2 / from_height_m)^exponent`,
#' floored at 0.13 m/s (the original `MIN_SPEED`); this floor applies only
#' inside this estimator. Inside the WBGT kernel the existing
#' [wbgt_liljegren()]`$min_wind_speed` control remains in force; do not
#' apply both clamps expecting a single raw wind to pass through them twice.
#'
#' @param wind Wind speed in m/s at `from_height_m`. Zero is valid; negative
#'   values are invalid. The stability class uses this original-height
#'   value.
#' @param from_height_m Measurement height of `wind` in metres. Must be
#'   positive. Rows already at 2 m pass through unchanged and do not require
#'   any stability inputs. (The original C left its estimated-speed output
#'   undefined at 2 m; this function never reproduces that defect.)
#' @param solar_w_m2 Solar irradiance in W/m2, used only for daytime rows
#'   to select the radiation class (>= 925, >= 675, >= 175, < 175). Must be
#'   finite and non-negative where required; may be `NA` on nighttime and
#'   at-height-2 rows.
#' @param daytime Logical (or 0/1 numeric) flag from solar geometry, not
#'   from whether irradiance is positive. Required on every estimated row;
#'   never defaulted.
#' @param delta_t_10m_2m_c Vertical temperature difference (10 m minus 2 m)
#'   in degrees C, used only for nighttime rows with wind below 2.5 m/s,
#'   where its sign selects the inversion class. Required exactly where it
#'   affects the class; may be `NA` elsewhere. No default sign is invented.
#' @param urban Logical (or 0/1 numeric) land-use flag selecting the urban
#'   versus rural exponent table. Required on every estimated row; no
#'   land-use class is assumed.
#' @param diagnostics Single logical. If `TRUE`, return row-aligned
#'   metadata instead of a bare vector.
#' @return Numeric wind speed in m/s at 2 m. Scalars expand and equal-length
#'   vectors are processed row-wise; `numeric(0)` is preserved; `NA` inputs
#'   propagate silently. Rows missing a required conditional input are `NA`
#'   without warning; physically invalid rows (negative wind, non-positive
#'   or non-finite height, negative or non-finite required radiation,
#'   non-finite required temperature difference) become `NA` with a summary
#'   warning. With `diagnostics = TRUE`, a data frame with `wind_2m` plus
#'   row-aligned `stability_class` (1..6, `NA` for pass-through rows),
#'   `exponent`, `adjustment` (the applied `(2 / from_height_m)^exponent`
#'   factor; 1 for pass-through rows), `floored` (whether the 0.13 m/s
#'   floor was applied), and `status`/`reason` row records.
#' @details
#' Assumptions inherited from the original method: the SRDT class is a
#' coarse surface-layer stability surrogate driven by wind, solar geometry
#' and irradiance; `solar_w_m2` should be the same forcing passed to the
#' WBGT kernel. The original C evaluates the radiation class on its
#' internally normalized solar value; when comparing against a full C
#' pipeline, use forcing where that normalization is the identity (see the
#' reference tests). Results are computed in double precision while the
#' original uses `float`, so agreement is to floating-point tolerance, not
#' bitwise. Conversion does not resolve exposure representativeness,
#' terrain or building effects, or time-averaging mismatches.
#' @references
#' Liljegren, J. C., Carhart, R. A., Lawday, P., Tschopp, S. and Sharp, R.
#' (2008). "Modeling the Wet Bulb Globe Temperature Using Standard
#' Meteorological Measurements." Journal of Occupational and Environmental
#' Hygiene, 5(10), 645-655. \doi{10.1080/15459620802310770}.
#'
#' U.S. EPA (2000). "Meteorological Monitoring Guidance for Regulatory
#' Modeling Applications." EPA-454/R-99-005, section 6.2.5.
#' @seealso [wind_at_height()] for explicit general height conversion
#' @examples
#' # 10 m rural daytime wind, mid-range radiation.
#' wind_2m_liljegren(4, from_height_m = 10, solar_w_m2 = 500,
#'   daytime = TRUE, delta_t_10m_2m_c = NA_real_, urban = FALSE)
#'
#' # Nighttime with a surface inversion (delta_t > 0 means stable).
#' wind_2m_liljegren(1.5, from_height_m = 10, solar_w_m2 = 0,
#'   daytime = FALSE, delta_t_10m_2m_c = 2, urban = FALSE)
#'
#' # Wind already at 2 m passes through without stability inputs.
#' wind_2m_liljegren(3.5, from_height_m = 2, solar_w_m2 = NA_real_,
#'   daytime = NA, delta_t_10m_2m_c = NA_real_, urban = NA)
#'
#' # Row-aligned metadata.
#' wind_2m_liljegren(c(4, 0.05), c(10, 10), c(500, 500), c(TRUE, TRUE),
#'   NA_real_, FALSE, diagnostics = TRUE)
#' @export
wind_2m_liljegren <- function(wind, from_height_m, solar_w_m2, daytime,
                              delta_t_10m_2m_c, urban,
                              diagnostics = FALSE) {
  .logical_control(diagnostics, "diagnostics")
  for (name in c("wind", "from_height_m", "solar_w_m2", "delta_t_10m_2m_c")) {
    x <- get(name) # nolint: unnecessary_assignment_linter.
    .assert(is.numeric(x) && is.null(dim(x)),
      paste0("'", name, "' must be a numeric vector"))
  }
  daytime <- .srdt_flag(daytime, "daytime")
  urban <- .srdt_flag(urban, "urban")
  inputs <- .align_inputs(list(wind = wind, from_height_m = from_height_m,
    solar_w_m2 = solar_w_m2, delta_t_10m_2m_c = delta_t_10m_2m_c,
    daytime = daytime, urban = urban))
  wind_v <- as.numeric(inputs$wind)
  from_v <- as.numeric(inputs$from_height_m)
  solar_v <- as.numeric(inputs$solar_w_m2)
  dt_v <- as.numeric(inputs$delta_t_10m_2m_c)
  day_v <- inputs$daytime
  urban_v <- inputs$urban
  n <- length(wind_v)

  status <- rep("valid", n)
  reason <- rep("", n)
  mark_missing <- function(rows, why) {
    rows <- which(rows & status == "valid")
    if (length(rows)) {
      status[rows] <<- "missing_input"
      reason[rows] <<- why
    }
  }
  mark_invalid <- function(rows, why) {
    rows <- which(rows & status != "invalid_input")
    if (length(rows)) {
      status[rows] <<- "invalid_input"
      reason[rows] <<- why
    }
  }
  is_missing <- function(x) is.na(x) & !is.nan(x)
  is_bad_num <- function(x, lower_bounded) {
    is.nan(x) | (!is.na(x) & (!is.finite(x) | (lower_bounded & x < 0)))
  }

  mark_missing(is_missing(wind_v), "wind")
  mark_invalid(is_bad_num(wind_v, TRUE), "wind")
  mark_missing(is_missing(from_v), "from_height_m")
  mark_invalid(is.nan(from_v) | (!is.na(from_v) & (!is.finite(from_v) |
    from_v <= 0)), "from_height_m")

  # Rows already at 2 m need no stability inputs at all.
  valid <- status == "valid"
  est_rows <- valid & from_v != .srdt_ref_height_m
  mark_missing(est_rows & is.na(day_v), "daytime")
  mark_missing(est_rows & is.na(urban_v), "urban")

  valid <- status == "valid"
  est_rows <- valid & from_v != .srdt_ref_height_m
  day_rows <- est_rows & day_v
  night_rows <- est_rows & !day_v
  # Radiation is required only on daytime rows; nighttime radiation is
  # ignored even when present and invalid.
  mark_missing(day_rows & is_missing(solar_v), "solar_w_m2")
  mark_invalid(day_rows & is_bad_num(solar_v, TRUE), "solar_w_m2")
  # The inversion sign only changes the class below 2.5 m/s at night, so
  # delta_t is required exactly there; elsewhere it is irrelevant.
  dt_rows <- night_rows & !is.na(wind_v) & wind_v < 2.5
  mark_missing(dt_rows & is_missing(dt_v), "delta_t_10m_2m_c")
  mark_invalid(dt_rows & is_bad_num(dt_v, FALSE), "delta_t_10m_2m_c")

  valid <- status == "valid"
  pass_rows <- valid & from_v == .srdt_ref_height_m
  est_rows <- valid & !pass_rows
  day_rows <- est_rows & day_v

  values <- rep(NA_real_, n)
  cls <- rep(NA_integer_, n)
  exponent <- rep(NA_real_, n)
  adjustment <- rep(NA_real_, n)
  floored <- rep(NA, n)
  floored[pass_rows] <- FALSE
  adjustment[pass_rows] <- 1
  values[pass_rows] <- wind_v[pass_rows]

  if (any(est_rows)) {
    rows <- which(est_rows)
    # delta_t is irrelevant at night at or above 2.5 m/s; neutralise it so
    # an NA there cannot contaminate the class lookup.
    dt_used <- dt_v
    dt_used[!(night_rows & wind_v < 2.5)] <- 0
    class_rows <- .srdt_stability_class(day_v[rows], wind_v[rows],
      solar_v[rows], dt_used[rows])
    exponent_rows <- ifelse(urban_v[rows], .srdt_urban_exp[class_rows],
      .srdt_rural_exp[class_rows])
    adj_rows <- (.srdt_ref_height_m / from_v[rows])^exponent_rows
    raw_rows <- wind_v[rows] * adj_rows
    values[rows] <- pmax(raw_rows, .srdt_min_speed)
    cls[rows] <- class_rows
    exponent[rows] <- exponent_rows
    adjustment[rows] <- adj_rows
    floored[rows] <- raw_rows < .srdt_min_speed
  }

  failed <- valid & !is.finite(values)
  values[!valid | failed] <- NA_real_
  # Missing rows stay silent in the v3 style; only invalid rows warn.
  counts <- c(invalid = sum(status == "invalid_input"),
    failed = sum(failed))
  counts <- counts[counts > 0L]
  if (length(counts)) {
    warning(paste0("wind_2m_liljegren: ",
      paste(names(counts), counts, sep = "="),
      ". Invalid rows are NA; see ?wind_2m_liljegren for validity rules."),
      call. = FALSE)
  }
  if (diagnostics) {
    return(data.frame(wind_2m = values, stability_class = cls,
      exponent = exponent, adjustment = adjustment, floored = floored,
      status = status, reason = reason, stringsAsFactors = FALSE))
  }
  values
}
