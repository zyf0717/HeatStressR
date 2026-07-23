batch_reason_vocabulary <- c("none", "non_finite", "unbracketed", "max_iterations",
  "residual_validation", "scalar_fallback_failed", "not_attempted")
input_status_vocabulary <- c("attempted", "missing_input", "missing_date", "invalid_dewpoint")

diagnostic_result <- function(n) {
  result <- seq_len(n)
  for (field in HeatStressR:::WBGT_DIAGNOSTIC_FIELDS) {
    value <- if (field %in% c("batch_iterations", "batch_evaluations",
      "bracket_evaluations", "fallback_evaluations", "total_evaluations")) {
      seq_len(n)
    } else if (field %in% c("used_fallback", "batch_converged", "batch_valid",
      "fallback_converged", "converged")) {
      rep(TRUE, n)
    } else if (field == "fallback_reason") {
      rep("none", n)
    } else {
      as.numeric(seq_len(n))
    }
    attr(result, field) <- value
  }
  result
}

test_that("expand_solver_diagnostics preserves alignment and rejects malformed metadata", {
  result <- diagnostic_result(2)
  expanded <- HeatStressR:::expand_solver_diagnostics(result, c(2L, 4L), 5L)
  expect_true(all(vapply(expanded, length, integer(1)) == 5L))
  expect_identical(expanded$converged, c(NA, TRUE, NA, TRUE, NA))
  expect_identical(expanded$fallback_reason,
    c("not_attempted", "none", "not_attempted", "none", "not_attempted"))
  expect_true(all(vapply(HeatStressR:::expand_solver_diagnostics(numeric(), integer(), 3L),
    length, integer(1)) == 3L))
  expect_error(HeatStressR:::expand_solver_diagnostics(result, 1L, 2L), "result length")
  attr(result, "converged") <- NULL
  expect_error(HeatStressR:::expand_solver_diagnostics(result, c(1L, 2L), 2L),
    "missing required")
  result <- diagnostic_result(2)
  attr(result, "extra") <- TRUE
  expect_error(HeatStressR:::expand_solver_diagnostics(result, c(1L, 2L), 2L),
    "unexpected")
  result <- diagnostic_result(2)
  attr(result, "lower") <- 1
  expect_error(HeatStressR:::expand_solver_diagnostics(result, c(1L, 2L), 2L),
    "must match")
})

test_that("diagnostics distinguish status precedence from solver failures", {
  dates <- as.POSIXct(c("2024-06-01", NA, NA, "2024-06-01"), tz = "UTC")
  result <- expect_no_warning(wbgt.Liljegren(
    tas = c(NA, 20, 20, 20), dewp = c(10, 25, 25, 10), wind = rep(1, 4),
    radiation = rep(0, 4), dates = dates, lon = 0, lat = 0, noNAs = FALSE,
    diagnostics = TRUE
  ))
  diagnostics <- result$diagnostics
  expect_identical(diagnostics$input_status,
    c("missing_input", "missing_date", "missing_date", "attempted"))
  expect_identical(diagnostics$attempted, c(FALSE, FALSE, FALSE, TRUE))
  expect_true(all(diagnostics$input_status %in% input_status_vocabulary))
  for (solver in list(diagnostics$Tg, diagnostics$Tnwb)) {
    expect_true(all(c("converged", "final_residual", "failure_reason") %in% names(solver)))
    expect_true(all(vapply(solver, length, integer(1)) == 4L))
  }
})

test_that("numerical failures emit one counted warning with aligned batch diagnostics", {
  warnings <- character()
  result <- withCallingHandlers(wbgt.Liljegren(
    tas = 22, dewp = 10, wind = 0, radiation = Inf,
    dates = as.POSIXct("2024-06-01", tz = "UTC"), lon = 0, lat = 0,
    engine = "batch", diagnostics = TRUE, solar_time = "date_noon"
  ), warning = function(w) {
    warnings <<- c(warnings, conditionMessage(w))
    invokeRestart("muffleWarning")
  })
  expect_length(warnings, 1L)
  expect_match(warnings, "failed for 1 of 1 attempted rows")
  expect_match(warnings, "Tg:")
  expect_match(warnings, "non-finite: 1")
  expect_match(warnings, "Complete WBGT was set to NA")
  for (solver in list(result$diagnostics$Tg, result$diagnostics$Tnwb)) {
    expect_true(all(vapply(solver, length, integer(1)) == 1L))
    expect_true(all(solver$fallback_reason %in% batch_reason_vocabulary))
  }
})

test_that("nighttime solar forcing is removed and geometry mismatches are recorded", {
  dates <- as.POSIXct(c("2024-06-01 00:00:00", "2024-06-01 12:00:00"), tz = "UTC")
  forced <- suppressWarnings(wbgt.Liljegren(c(20, 20), c(10, 10), c(1, 1),
    c(100, 100), dates, lon = 0, lat = 0, hour = TRUE, diagnostics = TRUE))
  nighttime <- suppressWarnings(wbgt.Liljegren(20, 10, 1, 0, dates[1],
    lon = 0, lat = 0, hour = TRUE))
  expect_identical(forced$diagnostics$solar_geometry_mismatch, c(TRUE, FALSE))
  expect_equal(forced$data[1], nighttime$data)
  expect_equal(forced$Tg[1], nighttime$Tg)
  expect_equal(forced$Tnwb[1], nighttime$Tnwb)
})
