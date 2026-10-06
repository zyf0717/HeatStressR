test_that("preprocessing preserves solar policy and rejects invalid forcing", {
  processed <- HeatStressR:::preprocess_liljegren_inputs(
    tas = c(20,20,NA_real_,20), dewp = c(25,10,10,10), wind = c(-1,1,1,1),
    radiation = c(-10,100,100,100), pressure = c(1010,1000,990,NA_real_),
    zenith = c(0,pi,NA_real_,0), diagnostics = TRUE)
  expect_identical(processed$input_valid, c(FALSE,TRUE,FALSE,FALSE))
  expect_identical(processed$valid_idx, 2L)
  expect_equal(processed$radiation, c(-10,0,100,100))
  expect_identical(processed$wind_clamped, rep(FALSE,4))
  expect_identical(processed$radiation_clamped, rep(FALSE,4))
  expect_identical(processed$radiation_zeroed_below_horizon, c(FALSE,TRUE,FALSE,FALSE))
})

test_that("preprocessing cap/reject uses an exact dew-point boundary", {
  run <- function(policy) HeatStressR:::preprocess_liljegren_inputs(
    tas = rep(20,3), dewp = c(20,20+5e-5,20+2e-4), wind = rep(1,3),
    radiation = rep(0,3), pressure = 1010, zenith = rep(0,3),
    dewpoint_policy = policy, diagnostics = TRUE)
  cap <- run("cap")
  expect_equal(cap$dewp, rep(20,3))
  expect_identical(cap$dewpoint_adjusted, c(FALSE,TRUE,TRUE))
  expect_true(all(cap$input_valid))
  reject <- run("na")
  expect_identical(reject$input_valid, c(TRUE,FALSE,FALSE))
  expect_identical(reject$input_status, c("attempted","invalid_dewpoint","invalid_dewpoint"))
})

test_that("compact preprocessing omits row diagnostic allocations", {
  args <- list(tas = 20, dewp = 10, wind = 1, radiation = 100,
    pressure = 1010, zenith = pi)
  result <- do.call(HeatStressR:::preprocess_liljegren_inputs, args)
  expect_false(any(c("wind_clamped", "radiation_clamped", "radiation_zeroed_below_horizon",
    "dewpoint_adjusted") %in% names(result)))
})
