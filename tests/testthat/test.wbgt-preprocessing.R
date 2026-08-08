test_that("Liljegren preprocessing preserves forcing and status policies", {
  processed <- HeatStressR:::preprocess_liljegren_inputs(
    tas = c(20, 20, NA, 20), dewp = c(25, 10, 10, 10),
    wind = c(-1, 1, 1, 1), radiation = c(-10, 100, 100, 100),
    pressure = c(1010, 1000, 990, NA),
    zenith = c(0, pi, NA, 0), noNAs = TRUE, swap = FALSE,
    dewpoint_tolerance = 1e-4
  )

  expect_identical(processed$tas, c(20, 20, NA, 20))
  expect_identical(processed$dewp, c(20, 10, 10, 10))
  expect_identical(processed$wind, c(0, 1, 1, 1))
  expect_identical(processed$radiation, c(0, 0, 100, 100))
  expect_identical(processed$Pair, c(1010, 1000, 990, NA_real_))
  expect_identical(processed$input_status,
    c("attempted", "attempted", "missing_input", "missing_input"))
  expect_identical(processed$input_valid, c(TRUE, TRUE, FALSE, FALSE))
  expect_identical(processed$valid_idx, c(1L, 2L))
  expect_identical(processed$solar_geometry_mismatch, c(FALSE, TRUE, FALSE, FALSE))
  expect_equal(processed$relh, dewp2hurs(processed$tas, processed$dewp))
})

test_that("Liljegren preprocessing implements every dewpoint policy", {
  run <- function(noNAs, swap) HeatStressR:::preprocess_liljegren_inputs(
    tas = c(20, 20, 20), dewp = c(20, 20 + 5e-5, 20 + 2e-4),
    wind = rep(1, 3), radiation = rep(0, 3), pressure = 1010,
    zenith = rep(0, 3), noNAs = noNAs, swap = swap,
    dewpoint_tolerance = 1e-4
  )

  capped <- run(TRUE, FALSE)
  expect_equal(capped$tas, rep(20, 3))
  expect_equal(capped$dewp, c(20, 20 + 5e-5, 20))
  expect_true(all(capped$input_valid))

  swapped <- run(TRUE, TRUE)
  expect_equal(swapped$tas, c(20, 20 + 5e-5, 20 + 2e-4))
  expect_equal(swapped$dewp, rep(20, 3))
  expect_true(all(swapped$input_valid))

  for (swap in c(FALSE, TRUE)) {
    rejected <- run(FALSE, swap)
    expect_identical(rejected$input_valid, c(TRUE, FALSE, FALSE))
    expect_identical(rejected$input_status,
      c("attempted", "invalid_dewpoint", "invalid_dewpoint"))
  }
})

test_that("Liljegren preprocessing allocates diagnostics only when requested", {
  args <- list(
    tas = c(20, 20, NA, 20), dewp = c(25, 10, 25, 25),
    wind = c(-1, 1, 1, 1), radiation = c(-10, 100, 100, 100),
    pressure = c(1010, 1000, 990, NA), zenith = c(pi, pi, 0, 0),
    noNAs = TRUE, swap = FALSE, dewpoint_tolerance = 1e-4
  )
  diagnostic_fields <- c("wind_clamped", "radiation_clamped",
    "radiation_zeroed_below_horizon", "dewpoint_adjusted")

  compact <- do.call(HeatStressR:::preprocess_liljegren_inputs, args)
  expect_false(any(diagnostic_fields %in% names(compact)))

  detailed <- do.call(HeatStressR:::preprocess_liljegren_inputs,
    c(args, list(diagnostics = TRUE)))
  expect_identical(detailed$wind_clamped, c(TRUE, FALSE, FALSE, FALSE))
  expect_identical(detailed$radiation_clamped, c(TRUE, FALSE, FALSE, FALSE))
  expect_identical(detailed$radiation_zeroed_below_horizon,
    c(FALSE, TRUE, FALSE, FALSE))
  expect_identical(detailed$dewpoint_adjusted, c(TRUE, FALSE, FALSE, TRUE))
})
