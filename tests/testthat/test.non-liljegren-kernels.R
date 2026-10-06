test_that("unaffected canonical methods match the frozen 2.4.0 valid corpus", {
  fixture <- readRDS(test_path("fixtures", "v2-valid.rds"))
  x <- fixture$inputs
  expected <- fixture$expected
  expect_lt(max(abs(wet_bulb_stull(x$tas, x$hurs) - expected$wbt)), 1e-10)
  expect_lt(max(abs(wbgt_simplified_indoor(x$tas, x$hurs) - expected$swbgt)), 1e-10)
  expect_lt(max(abs(apparent_temperature(x$tas, x$hurs, x$wind) - expected$apparentTemp)), 1e-10)
  expect_lt(max(abs(effective_temperature(x$tas, x$hurs, x$wind) - expected$effectiveTemp)), 1e-10)
  expect_lt(max(abs(humidex(x$tas, x$hurs) - expected$humidex)), 1e-10)
  expect_lt(max(abs(discomfort_index(x$tas, x$hurs) - expected$discomInd)), 1e-10)
  expect_lt(max(abs(wbgt_bernard(x$tas, x$dewp) - expected$bernard$data)), 1e-4)
})

test_that("paired humidity conversions cover both phase conventions", {
  tas <- c(-40, -10, -0.1, 0, 0.1, 20, 35)
  hurs <- c(5, 50, 80, 90, 99, 60, 100)
  dewp <- HeatStressR:::.dew_point_c(tas, hurs)
  expect_equal(relative_humidity(tas, dewp), hurs, tolerance = 1e-12)
  expect_equal(vapour_pressure(0, 100), 6.107, tolerance = 1e-12)
  expect_equal(vapour_pressure(c(-10, 20), 50),
    c(6.108 * exp(17.856 * -10 / 235.52), 6.107 * exp(17.368 * 20 / 258.83)) / 2,
    tolerance = 1e-12)
  expect_identical(vapour_pressure(numeric(), numeric()), numeric())
  expect_identical(HeatStressR:::.dew_point_c(20, 0), -Inf)
})

test_that("simplified WBGT variants have distinct published coefficients", {
  e <- 6.107 * exp(17.368 * 30 / (238.83 + 30)) * 0.7
  expect_equal(wbgt_simplified_abm(30, 70), 0.567 * 30 + 0.393 * e + 3.94, tolerance = 1e-12)
  expect_equal(wbgt_simplified_indoor(30, 70), 0.567 * 30 + 0.216 * e + 3.38, tolerance = 1e-12)
})
