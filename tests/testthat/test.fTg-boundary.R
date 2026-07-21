####################################################################
#
# Regression test for adaptive fTg() bracketing.
#
####################################################################

context("Globe-temperature boundary behaviour")

test_that("adaptive fTg bracketing corrects the former upper-bound clipping", {
  globe_temperature <- HeatStressR:::fTg(
    tas = 30,
    relh = 50,
    Pair = 1010,
    wind = 0,
    min.speed = 0.1,
    radiation = 1000,
    propDirect = 0.8,
    zenith = HeatStressR:::degToRad(30),
    tolerance = 1e-4
  )

  expect_equal(globe_temperature, 68.49534, tolerance = 1e-4)
  expect_gt(globe_temperature, 30 + 10)
})
