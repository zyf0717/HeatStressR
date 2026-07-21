batch_fallback_fixture <- function() {
  list(
    tas = c(20, 30), dewp = c(15, 20), relh = c(70, 55), wind = c(1, 0.2),
    radiation = c(0, 400), zenith = HeatStressR:::degToRad(c(90, 45))
  )
}

run_batch_solver <- function(kind, ...) {
  x <- batch_fallback_fixture()
  if (identical(kind, "Tg")) {
    HeatStressR:::fTg_batch(x$tas, x$relh, 1010, x$wind, 0.1, x$radiation,
      0.8, x$zenith, ...)
  } else {
    HeatStressR:::fTnwb_batch(x$tas, x$dewp, x$relh, 1010, x$wind, 0.1,
      x$radiation, 0.8, x$zenith, ...)
  }
}

scalar_solver <- function(kind) {
  if (identical(kind, "Tg")) HeatStressR:::fTg_solution else HeatStressR:::fTnwb_solution
}

fake_batch_solver <- function(converged, failure_reason) {
  function(residual, lower, upper, lower_limit, upper_limit, ...) {
    n <- length(lower)
    list(root = if (converged) rep(0, n) else rep(NA_real_, n),
      converged = rep(converged, n), iterations = rep(1L, n),
      evaluations = rep(2L, n), residual = rep(NA_real_, n), lower = lower,
      upper = upper, failure_reason = rep(failure_reason, n))
  }
}

test_that("batch solvers accept valid vector solutions without fallback", {
  for (kind in c("Tg", "Tnwb")) {
    result <- run_batch_solver(kind)
    expect_true(all(attr(result, "batch_converged")))
    expect_true(all(attr(result, "batch_valid")))
    expect_false(any(attr(result, "used_fallback")))
    expect_true(all(is.na(attr(result, "fallback_converged"))))
    expect_true(all(attr(result, "converged")))
    expect_identical(attr(result, "fallback_reason"), rep("none", length(result)))
    expect_identical(attr(result, "fallback_evaluations"), integer(length(result)))
    expect_identical(attr(result, "total_evaluations"), attr(result, "batch_evaluations"))
  }
})

test_that("batch residual validation deterministically triggers successful fallback", {
  for (kind in c("Tg", "Tnwb")) {
    result <- run_batch_solver(kind,
      root_solver = fake_batch_solver(TRUE, "none"), scalar_solver = scalar_solver(kind))
    expect_true(all(attr(result, "batch_converged")))
    expect_false(any(attr(result, "batch_valid")))
    expect_true(all(attr(result, "used_fallback")))
    expect_true(all(attr(result, "fallback_converged")))
    expect_true(all(attr(result, "converged")))
    expect_true(all(is.finite(result)))
    expect_lte(max(abs(attr(result, "final_residual"))), 1e-4)
    expect_identical(attr(result, "fallback_reason"), rep("residual_validation", length(result)))
    expect_identical(attr(result, "total_evaluations"),
      attr(result, "batch_evaluations") + attr(result, "fallback_evaluations"))
  }
})

test_that("batch solvers safely reject failed scalar fallbacks", {
  failed_scalar <- function(...) list(root = NA_real_, converged = FALSE, evaluations = 7L)
  for (kind in c("Tg", "Tnwb")) {
    result <- run_batch_solver(kind,
      root_solver = fake_batch_solver(TRUE, "none"), scalar_solver = failed_scalar)
    expect_true(all(attr(result, "used_fallback")))
    expect_false(any(attr(result, "fallback_converged")))
    expect_false(any(attr(result, "converged")))
    expect_true(all(is.na(result)))
    expect_true(all(is.na(attr(result, "final_residual"))))
    expect_identical(attr(result, "fallback_reason"),
      rep("scalar_fallback_failed", length(result)))
    expect_identical(attr(result, "fallback_evaluations"), rep(7L, length(result)))
  }
})

test_that("unbracketed and iteration-limited batch rows retain fallback context", {
  for (failure_reason in c("unbracketed", "max_iterations")) {
    for (kind in c("Tg", "Tnwb")) {
      result <- run_batch_solver(kind,
        root_solver = fake_batch_solver(FALSE, failure_reason), scalar_solver = scalar_solver(kind))
      expect_false(any(attr(result, "batch_converged")))
      expect_true(all(attr(result, "used_fallback")))
      expect_true(all(attr(result, "fallback_converged")))
      expect_true(all(attr(result, "converged")))
      expect_identical(attr(result, "fallback_reason"), rep(failure_reason, length(result)))
      expect_lte(max(abs(attr(result, "final_residual"))), 1e-4)
    }
  }
})
