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
