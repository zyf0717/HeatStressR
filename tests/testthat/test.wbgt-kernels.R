context("Vectorized WBGT kernels")

test_that("heat-transfer and diffusivity kernels preserve scalar values", {
  temperature <- c(270, 300, 340)
  speed <- c(0, 0.1, 2)
  expect_equal(
    HeatStressR:::h_sphere_in_air_core(temperature, 1010, speed, 0.1, 0.05),
    vapply(seq_along(temperature), function(i) HeatStressR:::h_sphere_in_air_core(
      temperature[i], 1010, speed[i], 0.1, 0.05), numeric(1))
  )
  expect_equal(
    HeatStressR:::h_cylinder_in_air_core(temperature, 1010, speed, 0.1, 0.007),
    vapply(seq_along(temperature), function(i) HeatStressR:::h_cylinder_in_air_core(
      temperature[i], 1010, speed[i], 0.1, 0.007), numeric(1))
  )
  coefficient <- HeatStressR:::diffusivity_coefficient(1010)
  expect_equal(HeatStressR:::diffusivity_from_coefficient(temperature, coefficient),
    HeatStressR:::diffusivity(temperature, 1010))
})

test_that("globe root location uses the fourth-power energy equation", {
  Tglobe <- c(280, 310)
  Tair <- c(275, 300)
  wind <- c(0.5, 1)
  longwave <- c(6e9, 7e9)
  solar <- c(1e8, 2e8)
  energy <- HeatStressR:::fTg_energy_residual(Tglobe, Tair, 1010, wind,
    longwave, solar)
  h <- HeatStressR:::h_sphere_in_air_core(0.5 * (Tglobe + Tair), 1010,
    wind, wind, 0.05)
  expected <- longwave - h / (0.95 * HeatStressR:::STEFAN_BOLTZMANN) *
    (Tglobe - Tair) + solar - Tglobe ^ 4
  expect_equal(energy, expected)
})
