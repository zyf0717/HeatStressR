context("Liljegren batch solvers")

batch_fixture <- function() {
  list(
    tas = c(20, 30, 35), dewp = c(15, 20, 25), relh = c(70, 55, 50),
    wind = c(0, 0.2, 1), radiation = c(0, 400, 1000),
    zenith = HeatStressR:::degToRad(c(90, 45, 30))
  )
}

test_that("batch solvers report residual-backed diagnostics", {
  x <- batch_fixture()
  tg <- HeatStressR:::fTg_batch(x$tas, x$relh, 1010, x$wind, 0.1,
    x$radiation, 0.8, x$zenith)
  tnwb <- HeatStressR:::fTnwb_batch(x$tas, x$dewp, x$relh, 1010, x$wind,
    0.1, x$radiation, 0.8, x$zenith)

  for (result in list(tg, tnwb)) {
    expect_length(result, length(x$tas))
    expect_true(all(is.finite(result)))
    expect_length(attr(result, "final_residual"), length(result))
    expect_true(all(c("batch_iterations", "batch_evaluations",
      "bracket_evaluations", "fallback_evaluations", "total_evaluations",
      "used_fallback", "batch_converged", "batch_residual", "batch_valid",
      "fallback_converged", "converged", "final_residual", "fallback_reason") %in%
      names(attributes(result))))
    accepted <- !is.na(result)
    expect_true(all(abs(attr(result, "final_residual")[accepted]) <= 1e-4))
  }
})

test_that("solver validation rejects finite residual-invalid values", {
  expect_false(HeatStressR:::valid_solver_result(300, 2e-4, 1e-4))
  expect_false(HeatStressR:::valid_solver_result(NA_real_, 0, 1e-4))
  expect_true(HeatStressR:::valid_solver_result(300, 1e-5, 1e-4))
})

test_that("failed scalar globe fallback is not returned as a finite value", {
  failed <- suppressWarnings(HeatStressR:::fTg_solution(
    tas = 22, relh = 50, Pair = 1010, wind = 0, min.speed = 0.1,
    radiation = 850, propDirect = 0.8, zenith = 1.54
  ))
  expect_false(failed$converged)
  expect_true(is.na(failed$root))
})

test_that("batch roots are bracketed, converged, and order invariant", {
  x <- batch_fixture()
  forward <- HeatStressR:::fTg_batch(x$tas, x$relh, 1010, x$wind, 0.1,
    x$radiation, 0.8, x$zenith)
  reverse <- HeatStressR:::fTg_batch(rev(x$tas), rev(x$relh), 1010,
    rev(x$wind), 0.1, rev(x$radiation), 0.8, rev(x$zenith))
  expect_equal(as.numeric(forward), as.numeric(rev(reverse)), tolerance = 1e-4)
  expect_true(all(attr(forward, "converged")))
  expect_true(all(abs(attr(forward, "final_residual")) <= 1e-4))
  expect_true(all(attr(forward, "lower") <= forward + 273.15 &
    forward + 273.15 <= attr(forward, "upper")))
})

test_that("batch solvers handle empty and single-row inputs", {
  x <- batch_fixture()
  expect_length(HeatStressR:::fTg_batch(numeric(), numeric(), 1010, numeric(),
    0.1, numeric(), 0.8, numeric()), 0)
  expect_length(HeatStressR:::fTnwb_batch(numeric(), numeric(), numeric(), 1010,
    numeric(), 0.1, numeric(), 0.8, numeric()), 0)
  expect_length(HeatStressR:::fTg_batch(x$tas[1], x$relh[1], 1010, x$wind[1],
    0.1, x$radiation[1], 0.8, x$zenith[1]), 1)
})

test_that("batch solvers reject mismatched inputs", {
  expect_error(HeatStressR:::fTg_batch(c(20, 21), 50, 1010, c(1, 1), 0.1,
    c(0, 0), 0.8, c(1, 1)), "same length")
  expect_error(HeatStressR:::fTnwb_batch(c(20, 21), c(15, 16), 50, 1010,
    c(1, 1), 0.1, c(0, 0), 0.8, c(1, 1)), "same length")
})

engine_fixture <- function() {
  list(
    tas = c(20, 35, 30, 25, 32, NA_real_, 28, 18),
    dewp = c(20, 10, 29, 5, 20, 10, 27, 17),
    wind = c(0, 0.1, 5, 0.05, 2, 1, 0.2, 8),
    radiation = c(0, 1000, 900, 0, 400, 200, 850, 20),
    dates = as.POSIXct("2020-02-28 00:00:00", tz = "UTC") +
      3600 * seq_len(8)
  )
}

test_that("Liljegren defaults to the corrected scalar engine", {
  x <- engine_fixture()
  default <- suppressWarnings(wbgt.Liljegren(x$tas, x$dewp, x$wind, x$radiation, x$dates,
    lon = -5.66, lat = 40.96, hour = TRUE, diagnostics = TRUE))
  scalar <- suppressWarnings(wbgt.Liljegren(x$tas, x$dewp, x$wind, x$radiation, x$dates,
    lon = -5.66, lat = 40.96, hour = TRUE, engine = "scalar"))
  expect_equal(default$data, scalar$data, tolerance = 0)
  expect_equal(default$Tg, scalar$Tg, tolerance = 0)
  expect_equal(default$Tnwb, scalar$Tnwb, tolerance = 0)
  expect_identical(default$diagnostics$engine, "scalar")
  expect_length(default$diagnostics$attempted, length(x$tas))
  expect_true(all(c("converged", "final_residual", "failure_reason") %in%
    names(default$diagnostics$Tg)))
  expect_identical(names(scalar), c("data", "Tnwb", "Tg"))
})

test_that("Liljegren batch engine is explicit and agrees with scalar", {
  x <- engine_fixture()
  batch <- suppressWarnings(wbgt.Liljegren(x$tas, x$dewp, x$wind, x$radiation, x$dates,
    lon = -5.66, lat = 40.96, hour = TRUE, engine = "batch", diagnostics = TRUE))
  scalar <- suppressWarnings(wbgt.Liljegren(x$tas, x$dewp, x$wind, x$radiation, x$dates,
    lon = -5.66, lat = 40.96, hour = TRUE, engine = "scalar"))
  expect_identical(batch$diagnostics$engine, "batch")
  for (component in c("data", "Tg", "Tnwb")) {
    expect_identical(is.na(batch[[component]]), is.na(scalar[[component]]))
    expect_equal(batch[[component]], scalar[[component]], tolerance = 1e-4)
  }
})

test_that("Liljegren groups solar geometry by row-aligned coordinates", {
  x <- engine_fixture()
  lon <- c(-5.66, -5.66, 0, 0, -5.66, 0, 0, -5.66)
  lat <- c(40.96, 40.96, 15, 15, 40.96, 15, 15, 40.96)
  expected_zenith <- vapply(seq_along(x$dates), function(i) {
    HeatStressR:::degToRad(calZenith(x$dates[i], lon[i], lat[i], hour = TRUE))
  }, numeric(1))
  actual_zenith <- HeatStressR:::calculate_liljegren_zenith(
    x$dates, lon, lat, hour = TRUE, gmt_offset = NULL, averaging_period = 0
  )
  expect_equal(actual_zenith, expected_zenith, tolerance = 0)

  scalar <- suppressWarnings(wbgt.Liljegren(
    x$tas, x$dewp, x$wind, x$radiation, x$dates, lon = lon, lat = lat,
    hour = TRUE, engine = "scalar"
  ))
  batch <- suppressWarnings(wbgt.Liljegren(
    x$tas, x$dewp, x$wind, x$radiation, x$dates, lon = lon, lat = lat,
    hour = TRUE, engine = "batch"
  ))
  for (component in c("data", "Tg", "Tnwb")) {
    expect_identical(is.na(batch[[component]]), is.na(scalar[[component]]))
    expect_equal(batch[[component]], scalar[[component]], tolerance = 1e-4)
  }
})

test_that("Liljegren reuses timestamp solar terms across coordinate groups", {
  dates <- rep(as.POSIXct(c("2024-03-20 06:00:00", "2024-03-20 18:00:00"),
    tz = "UTC"), 3)
  lon <- c(-90, 0, 90, -90, 0, 90)
  lat <- c(0, 15, -30, 0, 15, -30)
  expected <- vapply(seq_along(dates), function(i) {
    HeatStressR:::degToRad(calZenith(dates[i], lon[i], lat[i], hour = TRUE))
  }, numeric(1))

  actual <- HeatStressR:::calculate_liljegren_zenith(
    dates, lon, lat, hour = TRUE, gmt_offset = NULL, averaging_period = 0
  )
  expect_equal(actual, expected, tolerance = 0)

  local_dates <- rep(c("2024-03-20 01:30:00", "2024-03-20 13:30:00"), 3)
  expected_local <- vapply(seq_along(local_dates), function(i) {
    HeatStressR:::degToRad(calZenith(local_dates[i], lon[i], lat[i], hour = TRUE,
      gmt_offset = -5, averaging_period = 60))
  }, numeric(1))
  actual_local <- HeatStressR:::calculate_liljegren_zenith(
    local_dates, lon, lat, hour = TRUE, gmt_offset = -5, averaging_period = 60
  )
  expect_equal(actual_local, expected_local, tolerance = 0)
})

test_that("diagnostics map batch solver rows to original inputs", {
  x <- engine_fixture()
  result <- suppressWarnings(wbgt.Liljegren(x$tas, x$dewp, x$wind, x$radiation,
    x$dates, lon = -5.66, lat = 40.96, hour = TRUE, engine = "batch",
    diagnostics = TRUE))
  diagnostics <- result$diagnostics
  expect_false(diagnostics$attempted[6])
  expect_identical(diagnostics$input_status[6], "missing_input")
  for (solver in list(diagnostics$Tg, diagnostics$Tnwb)) {
    expect_true(all(vapply(solver, length, integer(1)) == length(x$tas)))
    expect_true(is.na(solver$final_residual[6]))
    expect_identical(solver$fallback_reason[6], "not_attempted")
  }
})

test_that("Liljegren rejects invalid engines", {
  x <- engine_fixture()
  expect_error(wbgt.Liljegren(x$tas, x$dewp, x$wind, x$radiation, x$dates,
    lon = -5.66, lat = 40.96, hour = TRUE, engine = "invalid"),
  "should be one of")
})

test_that("energy-form globe roots resolve the engine fixture", {
  x <- engine_fixture()
  result <- expect_no_warning(wbgt.Liljegren(x$tas, x$dewp, x$wind, x$radiation,
    x$dates, lon = -5.66, lat = 40.96, hour = TRUE, engine = "batch"),
  )
  expect_identical(is.na(result$data), is.na(result$Tg) | is.na(result$Tnwb))
})

test_that("missing inputs do not produce solver-failure warnings", {
  dates <- as.POSIXct("2020-02-28", tz = "UTC") + 0:4 * 3600
  expect_no_warning(wbgt.Liljegren(
    tas = c(NA, 20, 20, 20, 20), dewp = c(10, NA, 10, 10, 10),
    wind = c(1, 1, NA, 1, 1), radiation = c(0, 0, 0, NA, 0),
    dates = as.POSIXct(c(dates[1:4], NA), tz = "UTC"), lon = -5.66,
    lat = 40.96, hour = TRUE
  ))
})
