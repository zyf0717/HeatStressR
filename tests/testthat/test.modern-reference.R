test_that("Romps and Lu reproduce the pinned authors' reference fixtures", {
  x <- read.csv(test_path("fixtures", "heatindex-0.0.2.csv"))
  wet <- wet_bulb_romps(x$tas, x$hurs, x$pressure, diagnostics = TRUE)
  hi <- heat_index_lu(x$tas, x$hurs, diagnostics = TRUE)
  expect_lt(max(abs(wet$values - x$wet_bulb_romps)), 1e-8)
  expect_lt(max(abs(hi$values - x$heat_index_lu)), 1e-8)
  expect_identical(wet$diagnostics$solver$dependency_version,
    as.character(packageVersion("heatindex")))
  expect_equal(wet$values, heatindex::wetbulb(x$pressure * 100, x$tas + 273.15,
    x$hurs / 100, verbose = FALSE) - 273.15, tolerance = 1e-10)
  expect_equal(hi$values, heatindex::heatindex(x$tas + 273.15, x$hurs / 100) - 273.15, tolerance = 1e-10)
})

test_that("thermodynamic wet bulb satisfies warm liquid-water limits", {
  tas <- c(20, 30, 40)
  expect_equal(wet_bulb_romps(tas, 100), tas, tolerance = 1e-8)
  dry <- wet_bulb_romps(tas, 0)
  humid <- wet_bulb_romps(tas, 50)
  expect_true(all(dry < humid & humid < tas))
  expect_true(all(wet_bulb_romps(tas, 50, 700) < wet_bulb_romps(tas, 50, 1010)))
})
