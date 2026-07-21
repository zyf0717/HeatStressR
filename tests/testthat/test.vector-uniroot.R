expect_valid_roots <- function(solved, tolerance) {
  successful <- solved$converged
  expect_true(all(solved$root[successful] >= solved$lower[successful]))
  expect_true(all(solved$root[successful] <= solved$upper[successful]))
  expect_lte(max(abs(solved$residual[successful])), tolerance)
  expect_true(all(solved$evaluations >= solved$iterations))
}

test_that("vector_uniroot preserves independently bracketed decreasing roots", {
  roots <- c(1, 2, 3)
  solved <- HeatStressR:::vector_uniroot(
    function(x, idx) roots[idx] - x, c(0, 0, 0), c(2, 3, 4),
    c(-10, -10, -10), c(10, 10, 10), tolerance = 1e-8
  )
  expect_true(all(solved$converged))
  expect_equal(solved$root, roots, tolerance = 1e-8)
  expect_valid_roots(solved, 1e-8)
})

test_that("vector_uniroot expands the required side of decreasing brackets", {
  residual <- function(x, idx) c(5, -5)[idx] - x
  solved <- HeatStressR:::vector_uniroot(residual, c(0, 0), c(2, 2),
    c(-10, -10), c(10, 10), tolerance = 1e-8)
  expect_true(all(solved$converged))
  expect_equal(solved$root, c(5, -5), tolerance = 1e-8)
  expect_gt(solved$upper[1], 2)
  expect_equal(solved$lower[1], 0)
  expect_lt(solved$lower[2], 0)
  expect_lte(solved$upper[2], 2)
  expect_identical(solved$failure_reason, c("none", "none"))
  expect_valid_roots(solved, 1e-8)
})

test_that("vector_uniroot isolates mixed row failures", {
  roots <- c(1, 5, -5, 20, 1)
  solved <- HeatStressR:::vector_uniroot(function(x, idx) {
    value <- roots[idx] - x
    value[idx == 5] <- NA_real_
    value
  }, rep(0, 5), rep(2, 5), rep(-10, 5), rep(10, 5), tolerance = 1e-8)
  expect_identical(solved$converged, c(TRUE, TRUE, TRUE, FALSE, FALSE))
  expect_equal(solved$root[1:3], c(1, 5, -5), tolerance = 1e-8)
  expect_identical(solved$failure_reason[4:5], c("unbracketed", "non_finite"))
  expect_true(all(is.na(solved$root[4:5])))
  expect_valid_roots(solved[setdiff(names(solved), "failure_reason")], 1e-8)
})

test_that("vector_uniroot returns initial endpoint roots directly", {
  roots <- c(0, 2)
  solved <- HeatStressR:::vector_uniroot(function(x, idx) roots[idx] - x,
    c(0, 0), c(2, 2), c(-1, -1), c(3, 3), tolerance = 1e-8)
  expect_true(all(solved$converged))
  expect_equal(solved$root, roots, tolerance = 0)
  expect_identical(solved$iterations, c(0L, 0L))
  expect_valid_roots(solved, 1e-8)
})

test_that("vector_uniroot reports maximum iteration failures", {
  solved <- HeatStressR:::vector_uniroot(function(x, idx) 2 - x ^ 2,
    0, 2, 0, 2, tolerance = 1e-12, max_iterations = 1L)
  expect_false(solved$converged)
  expect_identical(solved$failure_reason, "max_iterations")
  expect_true(is.na(solved$root) || abs(solved$residual) > 1e-12)
  expect_gte(solved$evaluations, solved$iterations)
})

test_that("vector_uniroot fails non-finite endpoint rows without affecting peers", {
  solved <- HeatStressR:::vector_uniroot(function(x, idx) {
    value <- c(1, 1)[idx] - x
    value[idx == 2] <- Inf
    value
  }, c(0, 0), c(2, 2), c(-1, -1), c(3, 3))
  expect_identical(solved$converged, c(TRUE, FALSE))
  expect_identical(solved$failure_reason, c("none", "non_finite"))
  expect_true(is.na(solved$root[2]))
})

test_that("vector_uniroot recovers from a non-finite secant candidate", {
  seen_candidate <- FALSE
  residual <- function(x, idx) {
    value <- 0.5 - x
    if (any(x == 0.5) && !seen_candidate) {
      seen_candidate <<- TRUE
      value[x == 0.5] <- NaN
    }
    value
  }
  solved <- HeatStressR:::vector_uniroot(residual, 0, 2, 0, 2, tolerance = 1e-8)
  expect_true(solved$converged)
  expect_equal(solved$root, 0.5, tolerance = 1e-8)
  expect_valid_roots(solved, 1e-8)
})

test_that("vector_uniroot fails safely when secant and midpoint are non-finite", {
  residual <- function(x, idx) ifelse(x %in% c(0.5, 1), NaN, 0.5 - x)
  solved <- HeatStressR:::vector_uniroot(residual, 0, 2, 0, 2)
  expect_false(solved$converged)
  expect_identical(solved$failure_reason, "non_finite")
  expect_true(is.na(solved$root))
  expect_true(is.na(solved$residual))
})

test_that("vector_uniroot supports coherent zero-length inputs", {
  solved <- HeatStressR:::vector_uniroot(function(x, idx) numeric(), numeric(),
    numeric(), numeric(), numeric())
  for (field in c("root", "converged", "iterations", "evaluations", "residual",
                  "lower", "upper", "failure_reason"))
    expect_length(solved[[field]], 0)
})

test_that("vector_uniroot rejects invalid controls", {
  root <- function(x, idx) 1 - x
  args <- list(root, 0, 2, -1, 3)
  expect_error(do.call(HeatStressR:::vector_uniroot, c(args, list(tolerance = 0))),
    "finite positive")
  expect_error(do.call(HeatStressR:::vector_uniroot, c(args, list(tolerance = Inf))),
    "finite positive")
  expect_error(do.call(HeatStressR:::vector_uniroot, c(args, list(max_iterations = 0))),
    "positive integer")
  expect_error(do.call(HeatStressR:::vector_uniroot, c(args, list(max_iterations = 1.5))),
    "positive integer")
  expect_error(HeatStressR:::vector_uniroot(root, c(0, 0), 2, c(-1, -1), c(3, 3)),
    "same length")
  expect_error(HeatStressR:::vector_uniroot(root, 2, 0, -1, 3), "lower must")
  expect_error(HeatStressR:::vector_uniroot(root, 0, 2, 1, 3), "lower_limit")
  expect_error(HeatStressR:::vector_uniroot(root, 0, 2, -1, 1), "upper_limit")
})
