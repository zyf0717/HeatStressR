test_that("fTnwb returns residual-validated roots beyond its initial interval", {
  solution <- HeatStressR:::fTnwb_solution(
    tas = 35, dewp = 10, relh = 20, Pair = 1010, wind = 0,
    min.speed = 0.1, radiation = 1000, propDirect = 0.8,
    zenith = HeatStressR:::degToRad(30)
  )
  expect_true(solution$converged)
  expect_lte(abs(solution$residual), 1e-4)
  expect_true(is.finite(solution$root))
})

test_that("batch wet-bulb values are residual validated", {
  x <- list(tas = c(20, 35), dewp = c(19, 10), relh = c(95, 20),
    wind = c(0, 0), radiation = c(0, 1000),
    zenith = HeatStressR:::degToRad(c(90, 30)))
  result <- HeatStressR:::fTnwb_batch(x$tas, x$dewp, x$relh, 1010, x$wind,
    0.1, x$radiation, 0.8, x$zenith)
  expect_true(all(attr(result, "converged")))
  expect_true(all(abs(attr(result, "final_residual")) <= 1e-4))
})

test_that("batch wet-bulb solver supports dew-point depressions over 99 C", {
  args <- list(
    tas = 45, dewp = -60, relh = HeatStressR:::dewp2hurs(45, -60), Pair = 1010,
    wind = 1, min.speed = 0.13, radiation = 700, propDirect = 0.8,
    zenith = HeatStressR:::degToRad(30)
  )
  batch <- HeatStressR:::fTnwb_batch(args$tas, args$dewp, args$relh, args$Pair, args$wind,
    args$min.speed, args$radiation, args$propDirect, args$zenith)
  scalar <- HeatStressR:::fTnwb_solution(args$tas, args$dewp, args$relh, args$Pair, args$wind,
    args$min.speed, args$radiation, args$propDirect, args$zenith)

  expect_true(attr(batch, "converged"))
  expect_true(scalar$converged)
  expect_equal(as.numeric(batch), scalar$root, tolerance = 1e-4)
})
