test_that("Rothfusz matches independent NWS procedure fixtures", {
  x <- read.csv(test_path("fixtures", "nws-heat-index.csv"))
  actual <- heat_index_rothfusz((x$temperature_f - 32) / 1.8, x$hurs)
  expect_lt(max(abs(actual - x$heat_index_c)), 1e-10)
  expect_equal(heat_index_rothfusz(35, 10), 31.9164373888888, tolerance = 1e-10)
  expect_equal(heat_index_rothfusz(25, 50), 24.9305555555556, tolerance = 1e-10)
  expect_true(is.na(heat_index_rothfusz(NA_real_, 50)))
})
