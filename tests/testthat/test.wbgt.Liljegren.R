####################################################################
#
# Package HeatStress
#
# Test for heat stress indices computation
#
###################################################################
library("HeatStress")
context("Heat Stress indices computation: WBGT Liljegren")


test_that("wbgt.Liljegren retains the fork regression fixture",{
  data("data_obs", envir = environment())
  tas <- data_obs$tasmean
  hurs <- data_obs$hurs
  dewp <- data_obs$dewp
  wind <- data_obs$wind
  solar <- data_obs$solar
  dates <- data_obs$Dates
  rows <- c(31, 40, 50)
  result <- wbgt.Liljegren(tas[rows], dewp[rows], wind[rows], solar[rows],
    dates[rows], -5.66, 40.96)

  expect_equal(result$data, c(13.85860, 22.40398, 18.55820), tolerance = 1e-4)
  expect_equal(result$Tnwb, c(12.12177, 18.79590, 15.88365), tolerance = 1e-4)
  expect_equal(result$Tg, c(18.66679, 32.93427, 26.29825), tolerance = 1e-4)
  
})
