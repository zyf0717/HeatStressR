test_that("power law matches the analytical formula", {
  expect_equal(wind_at_height(4, 10, 2, method = "power", exponent = 1 / 7),
    4 * (2 / 10)^(1 / 7))
  expect_equal(wind_at_height(6, 2, 10, method = "power", exponent = 0.2),
    6 * (10 / 2)^0.2)
  # Exponent may be row-wise.
  expect_equal(wind_at_height(c(4, 4), 10, 2, method = "power",
    exponent = c(0.1, 0.2)), c(4 * 0.2^0.1, 4 * 0.2^0.2))
})

test_that("neutral log law matches the analytical formula", {
  expect_equal(wind_at_height(4, 10, 2, method = "neutral_log",
    roughness_length_m = 0.1), 4 * log(2 / 0.1) / log(10 / 0.1))
  expect_equal(wind_at_height(4, 10, 2, method = "neutral_log",
    roughness_length_m = 0.01, displacement_height_m = 1),
  4 * log((2 - 1) / 0.01) / log((10 - 1) / 0.01))
})

test_that("equal heights return the wind unchanged", {
  expect_equal(wind_at_height(c(0, 3, NA_real_), 10, 10, method = "power",
    exponent = 0.143), c(0, 3, NA_real_))
  # Equal heights are exempt from method-parameter row validity.
  expect_equal(wind_at_height(3, 10, 10, method = "neutral_log",
    roughness_length_m = 0.1, displacement_height_m = 9.5), 3)
})

test_that("converted wind falls monotonically from 10 m to 2 m", {
  for (e in c(0.05, 0.143, 0.4)) {
    expect_lt(wind_at_height(5, 10, 2, method = "power", exponent = e), 5)
  }
  for (z0 in c(0.001, 0.03, 0.1)) {
    expect_lt(wind_at_height(5, 10, 2, method = "neutral_log",
      roughness_length_m = z0), 5)
  }
  # And rises back up when converting upward.
  u2 <- wind_at_height(5, 10, 2, method = "neutral_log", roughness_length_m = 0.1)
  expect_equal(wind_at_height(u2, 2, 10, method = "neutral_log",
    roughness_length_m = 0.1), 5)
})

test_that("zero wind is valid and stays zero; no minimum-wind clamp", {
  expect_equal(wind_at_height(0, 10, 2, method = "power", exponent = 0.143), 0)
  expect_equal(wind_at_height(0, 10, 2, method = "neutral_log",
    roughness_length_m = 0.1), 0)
})

test_that("shapes: scalar expansion, vector alignment, empty, NA", {
  expect_equal(wind_at_height(numeric(0), 10, 2, method = "power",
    exponent = 0.143), numeric(0))
  expect_equal(wind_at_height(numeric(0), numeric(0), 2, method = "power",
    exponent = 0.143), numeric(0))
  expect_length(wind_at_height(rep(4, 5), 10, 2, method = "power",
    exponent = 0.143), 5L)
  expect_equal(wind_at_height(c(4, 5), c(10, 50), 2, method = "power",
    exponent = 0.143), c(4, 5) * (2 / c(10, 50))^0.143)
  expect_equal(wind_at_height(NA_real_, 10, 2, method = "power",
    exponent = 0.143), NA_real_)
  expect_silent(wind_at_height(c(4, NA_real_), 10, 2, method = "power",
    exponent = 0.143))
})

test_that("malformed shapes and missing method parameters are call errors", {
  expect_error(wind_at_height(c(1, 2, 3), c(10, 50), 2, method = "power",
    exponent = 0.143), "same length")
  expect_error(wind_at_height(matrix(4, 1, 1), 10, 2, method = "power",
    exponent = 0.143), "numeric vector")
  expect_error(wind_at_height(4, 10, 2, method = "power"), "exponent")
  expect_error(wind_at_height(4, 10, 2, method = "neutral_log"), "roughness")
  expect_error(wind_at_height(4, 10, 2), "arg")
  expect_error(wind_at_height(4, 10, 2, method = "log"), "should be one of")
  expect_error(wind_at_height(4, 10, 2, method = "neutral_log",
    roughness_length_m = numeric(0)), "numeric vector")
})

test_that("physically invalid rows become NA with a summary warning", {
  expect_warning(u <- wind_at_height(c(4, -1), 10, 2, method = "power",
    exponent = 0.143), "invalid=1")
  expect_equal(u, c(4 * 0.2^0.143, NA_real_))

  expect_warning(wind_at_height(4, 0, 2, method = "power", exponent = 0.143),
    "invalid=1")
  expect_warning(wind_at_height(4, 10, -2, method = "power", exponent = 0.143),
    "invalid=1")
  expect_warning(wind_at_height(4, Inf, 2, method = "power", exponent = 0.143),
    "invalid=1")
  expect_warning(wind_at_height(4, 10, 2, method = "power", exponent = NaN),
    "invalid=1")
  expect_warning(wind_at_height(4, 10, 2, method = "neutral_log",
    roughness_length_m = 0), "invalid=1")
  # Height at or below d + z0 is inadmissible for the log law.
  expect_warning(wind_at_height(4, 10, 2, method = "neutral_log",
    roughness_length_m = 0.5, displacement_height_m = 1.6), "invalid=1")
  # Negative zero-plane displacement height is physically invalid.
  expect_warning(wind_at_height(4, 10, 2, method = "neutral_log",
    roughness_length_m = 0.1, displacement_height_m = -0.5), "invalid=1")
  expect_warning(u <- wind_at_height(c(4, 4), 10, 2, method = "neutral_log",
    roughness_length_m = 0.1, displacement_height_m = c(0, -0.5)),
    "invalid=1")
  expect_equal(u[1], 4 * log(2 / 0.1) / log(10 / 0.1))
  expect_equal(u[2], NA_real_)
  expect_warning(u <- wind_at_height(c(4, 4), 10, 2, method = "neutral_log",
    roughness_length_m = c(0.1, -1)), "invalid=1")
  expect_equal(u[2], NA_real_)
  # NaN wind is an invalid physical row, not a silent missing value.
  expect_warning(wind_at_height(NaN, 10, 2, method = "power", exponent = 0.1),
    "invalid=1")
})

test_that("conversion composes with wbgt_liljegren as plain preprocessing", {
  u10 <- 3
  u2 <- wind_at_height(u10, 10, 2, method = "neutral_log",
    roughness_length_m = 0.1)
  args <- list(tas = 30, dewp = 20, wind = u2, radiation = 700,
    time = "2024-06-01T12:00:00Z", lon = 103.8, lat = 1.3)
  direct <- do.call(wbgt_liljegren, args)
  inline <- do.call(wbgt_liljegren, utils::modifyList(args,
    list(wind = wind_at_height(u10, 10, 2, method = "neutral_log",
      roughness_length_m = 0.1))))
  expect_equal(direct, inline)
})

test_that("no implicit wind-height pathway was added to existing kernels", {
  expect_false("wind_height" %in% names(formals(wbgt_liljegren)))
  expect_false("wind_height_m" %in% names(formals(wbgt_liljegren)))
  expect_false("wind_10m" %in% names(formals(wbgt_liljegren)))
  hi_formals <- names(formals(heat_indices))
  expect_true(all(c("wind_10m", "wind_2m") %in% hi_formals))
})

# --- wind_2m_liljegren(): SRDT stability-class estimator ---

test_that("daytime wind thresholds 2/3/5/6 m/s select the class rows", {
  cls <- function(w) suppressWarnings(
    wind_2m_liljegren(w, 10, 500, TRUE, NA_real_, FALSE, diagnostics = TRUE)$stability_class)
  # solar 500 W/m2 is the >= 175 column: classes 2,3,3,3,3,4,4,4.
  expect_equal(cls(c(1.99, 2, 2.99, 3, 4.99, 5, 5.99, 6)),
    c(2, 3, 3, 3, 3, 4, 4, 4))
})

test_that("daytime radiation thresholds 175/675/925 W/m2 select the columns", {
  cls <- function(s) suppressWarnings(
    wind_2m_liljegren(4, 10, s, TRUE, NA_real_, FALSE, diagnostics = TRUE)$stability_class)
  # wind 4 m/s is the 3-5 m/s row: classes 4,3,3,2,2,2 across the columns.
  expect_equal(cls(c(174.99, 175, 674.99, 675, 924.99, 925)),
    c(4, 3, 3, 2, 2, 2))
})

test_that("nighttime wind thresholds 2/2.5 m/s and delta_t sign select classes", {
  cls <- function(w, dt) suppressWarnings(
    wind_2m_liljegren(w, 10, 0, FALSE, dt, FALSE, diagnostics = TRUE)$stability_class)
  # delta_t < 0 (neutral/mixed): 5, 5, 4 across the wind rows.
  expect_equal(cls(c(1.99, 2, 2.49, 2.5), -1), c(5, 5, 5, 4))
  # delta_t >= 0 (inversion): 6, 6, 6, 4; zero counts as inversion (>= 0).
  expect_equal(cls(c(1.99, 2, 2.49, 2.5), 1), c(6, 6, 6, 4))
  expect_equal(cls(1.5, 0), 6)
  expect_equal(cls(1.5, -0.001), 5)
})

test_that("all six SRDT classes are reachable", {
  seen <- c(
    suppressWarnings(wind_2m_liljegren(1, 10, 925, TRUE, NA_real_, FALSE, diagnostics = TRUE)$stability_class),
    suppressWarnings(wind_2m_liljegren(1, 10, 500, TRUE, NA_real_, FALSE, diagnostics = TRUE)$stability_class),
    suppressWarnings(wind_2m_liljegren(4, 10, 500, TRUE, NA_real_, FALSE, diagnostics = TRUE)$stability_class),
    suppressWarnings(wind_2m_liljegren(6, 10, 500, TRUE, NA_real_, FALSE, diagnostics = TRUE)$stability_class),
    suppressWarnings(wind_2m_liljegren(1, 10, 0, FALSE, -1, FALSE, diagnostics = TRUE)$stability_class),
    suppressWarnings(wind_2m_liljegren(1, 10, 0, FALSE, 1, FALSE, diagnostics = TRUE)$stability_class))
  expect_equal(sort(unique(seen)), 1:6)
})

test_that("rural and urban exponent tables are applied separately", {
  # Class 3 at 10 m: rural exponent 0.10, urban exponent 0.20.
  u_rural <- wind_2m_liljegren(4, 10, 500, TRUE, NA_real_, FALSE)
  u_urban <- wind_2m_liljegren(4, 10, 500, TRUE, NA_real_, TRUE)
  expect_equal(u_rural, 4 * (2 / 10)^0.10)
  expect_equal(u_urban, 4 * (2 / 10)^0.20)
  # Class 6: rural 0.55, urban 0.30.
  expect_equal(wind_2m_liljegren(1, 10, 0, FALSE, 1, FALSE), 1 * (0.2)^0.55)
  expect_equal(wind_2m_liljegren(1, 10, 0, FALSE, 1, TRUE), 1 * (0.2)^0.30)
})

test_that("class uses the original-height wind before conversion", {
  # 6 m/s at 50 m is the >= 6 m/s class row, not whatever 2 m value results.
  d <- suppressWarnings(wind_2m_liljegren(6, 50, 500, TRUE, NA_real_, FALSE,
    diagnostics = TRUE))
  expect_equal(d$stability_class, 4L)
  expect_equal(d$wind_2m, 6 * (2 / 50)^0.15)
})

test_that("wind at 2 m passes through without stability inputs", {
  expect_silent(wind_2m_liljegren(3.5, 2, NA_real_, NA, NA_real_, NA))
  expect_equal(wind_2m_liljegren(c(0, 3.5, NA_real_), 2, NA_real_, NA, NA_real_, NA),
    c(0, 3.5, NA_real_))
  # No floor, no exponent, even where the estimator would otherwise clamp.
  expect_equal(wind_2m_liljegren(0.01, 2, NA_real_, NA, NA_real_, NA), 0.01)
  # Invalid rows at 2 m still validate as ordinary wind/height rows.
  expect_warning(wind_2m_liljegren(-1, 2, NA_real_, NA, NA_real_, NA), "invalid=1")
})

test_that("calm floor 0.13 m/s applies only in this estimator", {
  expect_equal(wind_2m_liljegren(0, 10, 500, TRUE, NA_real_, FALSE), 0.13)
  expect_equal(wind_2m_liljegren(0.01, 10, 0, FALSE, 1, FALSE), 0.13)
  d <- suppressWarnings(wind_2m_liljegren(c(0.01, 4), 10, 500, TRUE, NA_real_,
    FALSE, diagnostics = TRUE))
  expect_equal(d$floored, c(TRUE, FALSE))
  expect_equal(d$wind_2m, c(0.13, 4 * (2 / 10)^0.10))
  # The generic converter never clamps.
  expect_equal(wind_at_height(0.01, 10, 2, method = "power", exponent = 0.1),
    0.01 * (2 / 10)^0.1)
})

test_that("conditional inputs: only the mathematically relevant ones are required", {
  # Daytime rows never need delta_t.
  expect_silent(wind_2m_liljegren(4, 10, 500, TRUE, NA_real_, FALSE))
  # Nighttime rows never need radiation, even invalid radiation is ignored.
  expect_silent(wind_2m_liljegren(4, 10, NA_real_, FALSE, 1, FALSE))
  expect_silent(wind_2m_liljegren(4, 10, -99, FALSE, 1, FALSE))
  # Nighttime at or above 2.5 m/s: class is 4 regardless of delta_t sign.
  expect_silent(wind_2m_liljegren(3, 10, 0, FALSE, NA_real_, FALSE))
  expect_equal(wind_2m_liljegren(3, 10, 0, FALSE, NA_real_, FALSE),
    wind_2m_liljegren(3, 10, 0, FALSE, 5, FALSE))
  # Missing required inputs are silent NA, never guessed defaults.
  expect_silent(wind_2m_liljegren(1, 10, 0, FALSE, NA_real_, FALSE))
  expect_silent(wind_2m_liljegren(4, 10, NA_real_, TRUE, NA_real_, FALSE))
  expect_silent(wind_2m_liljegren(4, 10, 500, TRUE, NA_real_, NA))
  expect_silent(wind_2m_liljegren(4, 10, 500, NA, NA_real_, FALSE))
})

test_that("diagnostics metadata is row-aligned", {
  d <- suppressWarnings(wind_2m_liljegren(c(4, 1, 1, -1), c(10, 10, 10, 10),
    c(500, 0, 0, 500), c(TRUE, FALSE, FALSE, TRUE), c(NA, 1, NA, NA),
    c(FALSE, FALSE, FALSE, FALSE), diagnostics = TRUE))
  expect_equal(nrow(d), 4L)
  expect_equal(d$status, c("valid", "valid", "missing_input", "invalid_input"))
  expect_equal(d$reason, c("", "", "delta_t_10m_2m_c", "wind"))
  expect_equal(d$stability_class, c(3L, 6L, NA, NA))
  expect_equal(d$exponent, c(0.10, 0.55, NA_real_, NA_real_))
  expect_equal(d$adjustment, c((2 / 10)^0.10, (2 / 10)^0.55, NA_real_, NA_real_))
  expect_equal(d$wind_2m[1:2], c(4, 1) * d$adjustment[1:2])
})

test_that("validation matches the v3 row policy", {
  expect_warning(wind_2m_liljegren(c(4, -1), 10, 500, TRUE, NA_real_, FALSE),
    "invalid=1")
  expect_warning(wind_2m_liljegren(4, 0, 500, TRUE, NA_real_, FALSE), "invalid=1")
  expect_warning(wind_2m_liljegren(4, Inf, 500, TRUE, NA_real_, FALSE), "invalid=1")
  expect_warning(wind_2m_liljegren(NaN, 10, 500, TRUE, NA_real_, FALSE), "invalid=1")
  expect_warning(wind_2m_liljegren(4, 10, -5, TRUE, NA_real_, FALSE), "invalid=1")
  expect_warning(wind_2m_liljegren(4, 10, Inf, TRUE, NA_real_, FALSE), "invalid=1")
  expect_warning(wind_2m_liljegren(1, 10, 0, FALSE, NaN, FALSE), "invalid=1")
  expect_silent(wind_2m_liljegren(c(4, NA_real_), 10, 500, TRUE, NA_real_, FALSE))
})

test_that("shapes: scalar expansion, vectors, empty, malformed calls", {
  expect_equal(wind_2m_liljegren(numeric(0), 10, 500, TRUE, NA_real_, FALSE),
    numeric(0))
  expect_equal(nrow(wind_2m_liljegren(numeric(0), 10, 500, TRUE, NA_real_, FALSE,
    diagnostics = TRUE)), 0L)
  expect_length(wind_2m_liljegren(rep(4, 5), 10, 500, TRUE, NA_real_, FALSE), 5L)
  expect_equal(wind_2m_liljegren(c(4, 4), c(10, 50), 500, TRUE, NA_real_, FALSE),
    4 * (2 / c(10, 50))^0.10)
  # 0/1 numeric flags are accepted for C-style callers.
  expect_equal(wind_2m_liljegren(4, 10, 500, 1, NA_real_, 0),
    wind_2m_liljegren(4, 10, 500, TRUE, NA_real_, FALSE))
  expect_error(wind_2m_liljegren(c(1, 2, 3), c(10, 50), 500, TRUE, NA_real_, FALSE),
    "same length")
  expect_error(wind_2m_liljegren(matrix(4, 1, 1), 10, 500, TRUE, NA_real_, FALSE),
    "numeric vector")
  expect_error(wind_2m_liljegren(4, 10, 500, 2, NA_real_, FALSE), "0 or 1")
  expect_error(wind_2m_liljegren(4, 10, 500, "yes", NA_real_, FALSE), "logical")
  expect_error(wind_2m_liljegren(4, 10, 500, TRUE, NA_real_, FALSE,
    diagnostics = "yes"), "single logical")
})
