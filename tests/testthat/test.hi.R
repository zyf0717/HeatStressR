test_that("hi returns the NWS heat index in degrees Celsius", {
  expect_equal(hi(30, 70), 35.038, tolerance = 1e-3)
  expect_equal(hi(25, 50), 24.8611, tolerance = 1e-4)
})

test_that("hi preserves missing values", {
  expect_true(is.na(hi(NA_real_, 50)))
})
