liljegren_tolerance_args <- function() {
  list(tas = 20, dewp = 10, wind = 1, radiation = 0,
    dates = as.POSIXct("2024-06-01", tz = "UTC"), lon = 0, lat = 0)
}

test_that("Liljegren validates independent tolerance controls", {
  args <- liljegren_tolerance_args()
  for (name in c("root_tolerance", "residual_tolerance", "dewpoint_tolerance")) {
    for (value in list(0, -1, NA_real_, Inf, c(1e-4, 1e-3))) {
      expect_error(do.call(wbgt.Liljegren, c(args, setNames(list(value), name))),
        "finite positive")
    }
  }
  expect_error(do.call(wbgt.Liljegren, c(args, list(residual_tolerance = 0.01 + 1e-12))),
    "must not exceed 0.01")
  expect_no_error(do.call(wbgt.Liljegren, c(args, list(residual_tolerance = 0.01))))
})

test_that("residual acceptance thresholds are independent from root precision", {
  residuals <- c(5e-5, 5e-4, 5e-3, 2e-2)
  expect_identical(HeatStressR:::valid_solver_result(rep(300, 4), residuals, 1e-4),
    c(TRUE, FALSE, FALSE, FALSE))
  expect_identical(HeatStressR:::valid_solver_result(rep(300, 4), residuals, 1e-3),
    c(TRUE, TRUE, FALSE, FALSE))
  expect_identical(HeatStressR:::valid_solver_result(rep(300, 4), residuals, 0.01),
    c(TRUE, TRUE, TRUE, FALSE))
  expect_false(HeatStressR:::valid_solver_result(300, Inf, 0.01))

  args <- liljegren_tolerance_args()
  loose <- do.call(wbgt.Liljegren, c(args, list(diagnostics = TRUE,
    root_tolerance = 1e-6, residual_tolerance = 0.01)))
  strict <- do.call(wbgt.Liljegren, c(args, list(diagnostics = TRUE,
    root_tolerance = 1e-6, residual_tolerance = 1e-4)))
  expect_identical(loose$diagnostics$Tg$root_tolerance,
    strict$diagnostics$Tg$root_tolerance)
  expect_identical(loose$diagnostics$Tnwb$root_tolerance,
    strict$diagnostics$Tnwb$root_tolerance)
})

test_that("dewpoint tolerance only changes the dewpoint policy", {
  args <- liljegren_tolerance_args()
  args$dewp <- args$tas + 5e-4
  loose <- do.call(wbgt.Liljegren, c(args, list(diagnostics = TRUE,
    dewpoint_tolerance = 1e-3)))
  strict <- do.call(wbgt.Liljegren, c(args, list(diagnostics = TRUE,
    dewpoint_tolerance = 1e-4)))
  expect_true(loose$diagnostics$attempted)
  expect_true(strict$diagnostics$attempted)
  expect_identical(loose$diagnostics$Tg$converged, strict$diagnostics$Tg$converged)
  expect_identical(loose$diagnostics$Tnwb$converged, strict$diagnostics$Tnwb$converged)
})

test_that("diagnostics expose component-level brackets and completeness", {
  args <- liljegren_tolerance_args()
  result <- do.call(wbgt.Liljegren, c(args, list(diagnostics = TRUE)))
  batch <- do.call(wbgt.Liljegren, c(args, list(diagnostics = TRUE, engine = "batch")))
  fields <- c("converged", "evaluations", "final_residual", "failure_reason",
    "used_fallback", "initial_lower", "initial_upper", "final_lower",
    "final_upper", "lower_residual", "upper_residual", "root_tolerance",
    "residual_tolerance")
  for (component in list(result$diagnostics$Tg, result$diagnostics$Tnwb)) {
    expect_true(all(fields %in% names(component)))
    expect_true(component$converged)
    expect_identical(component$failure_reason, "none")
    expect_lte(abs(component$final_residual), component$residual_tolerance)
  }
  expect_identical(result$diagnostics$complete_wbgt,
    result$diagnostics$Tg$converged & result$diagnostics$Tnwb$converged)
  for (component in list(batch$diagnostics$Tg, batch$diagnostics$Tnwb)) {
    expect_true(all(fields %in% names(component)))
    accepted <- component$converged
    expect_true(all(abs(component$final_residual[accepted]) <=
      component$residual_tolerance[accepted]))
  }
  expect_identical(batch$diagnostics$complete_wbgt,
    batch$diagnostics$Tg$converged & batch$diagnostics$Tnwb$converged)
})
