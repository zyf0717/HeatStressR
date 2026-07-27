test_that("hi returns the NWS heat index in degrees Celsius", {
  expect_equal(hi(30, 70), 35.038, tolerance = 1e-3)
  expect_equal(hi(25, 50), 24.8611, tolerance = 1e-4)
})

test_that("hi preserves missing values", {
  expect_true(is.na(hi(NA_real_, 50)))
})

legacy_hi <- function(tas, hurs) {
  safe_filter <- function(condition) {
    condition[is.na(condition)] <- FALSE
    condition
  }
  tasf <- tas * 1.8 + 32
  simple <- 0.5 * (tasf + 61 + (tasf - 68) * 1.2 + hurs * 0.094)
  result <- -42.379 + 2.04901523 * tasf + 10.14333127 * hurs -
    0.22475541 * tasf * hurs - 6.83783e-3 * tasf ^ 2 -
    5.481717e-2 * hurs ^ 2 + 1.22874e-3 * tasf ^ 2 * hurs +
    8.5282e-4 * tasf * hurs ^ 2 - 1.99e-6 * tasf ^ 2 * hurs ^ 2
  low_humidity <- safe_filter(tasf >= 80 & tasf <= 112 & hurs <= 13)
  high_humidity <- safe_filter(tasf >= 80 & tasf <= 87 & hurs > 85)
  cool <- safe_filter(tasf < 80)
  simple_result <- safe_filter((simple + tasf) / 2 < 80)
  result[low_humidity] <- result[low_humidity] - (13 - hurs[low_humidity]) / 4 *
    sqrt(17 - abs(tasf[low_humidity] - 95) / 17)
  result[high_humidity] <- result[high_humidity] + (hurs[high_humidity] - 85) / 10 *
    ((87 - tasf[high_humidity]) / 5)
  result[cool] <- simple[cool]
  result[simple_result] <- simple[simple_result]
  (result - 32) / 1.8
}

test_that("hi selectively evaluates Rothfusz with legacy-equivalent results", {
  tasf <- c(79.999, 80, 87, 112, 112.001, 90, 90, 80, 87, NA_real_)
  hurs <- c(50, 85, 85, 13, 13, 13, 14, 86, 86, 50)
  tas <- (tasf - 32) / 1.8

  expect_equal(hi(tas, hurs), legacy_hi(tas, hurs), tolerance = 1e-12)
  expect_equal(
    hi(c(-5, 20, 30, 40), c(50, 50, 70, 40)),
    legacy_hi(c(-5, 20, 30, 40), c(50, 50, 70, 40)),
    tolerance = 1e-12
  )
})
