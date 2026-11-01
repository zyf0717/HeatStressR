# Golden-value comparison of wind_2m_liljegren() against the retained
# Liljegren v1.1 C source (stab_srdt() and est_wind_speed() in
# wbgt.c.original). The fixtures in fixtures/srdt-c-reference.csv were
# generated once by tools/generate-srdt-fixtures.R, which compiles the C
# functions verbatim from the pinned source (lwbgt commit
# 43d6af0f709b1403df85336307879041718f6c65). Ordinary test runs compare
# against the stored fixtures and need no compiler or external checkout.
#
# Solar normalization is matched by construction: the C pipeline evaluates the
# radiation class on its internally normalized solar value
# (min(solar/toasolar, 0.85) * toasolar). Every fixture value is at most
# 925 W/m2, which is at most 0.85 * top-of-atmosphere irradiance near local
# noon in low latitudes (toasolar ~ 1367 W/m2), so a full-pipeline C run at
# such a time/location applies the identity normalization to these fixtures.
#
# Rows with zspeed == 2 are never compared: the original leaves its
# estimated-speed output unwritten there (documented undefined-output defect,
# see lwbgt docs/DEVIATIONS.md). The R pass-through at 2 m is covered by
# test.wind-height.R instead.
#
# Float-precision caveat: the C reference computes in float (pow in double,
# result rounded to float); the R estimator uses double. The estimator
# reproduces the SRDT algorithm subject to floating-point differences, so
# agreement is asserted at a relative tolerance of 1e-6, well above float
# rounding (~1e-7) and far below any class-boundary effect.

SRDT_C_TOLERANCE <- 1e-6

srdt_fixtures <- function() {
  read.csv(test_path("fixtures", "srdt-c-reference.csv"),
    comment.char = "#", stringsAsFactors = FALSE)
}

test_that("SRDT fixtures cover all six classes and the calm floor", {
  fixtures <- srdt_fixtures()
  expect_gte(nrow(fixtures), 400L)
  expect_equal(sort(unique(fixtures$stability_class)), 1:6)
  expect_true(any(abs(fixtures$est_speed - 0.13) < SRDT_C_TOLERANCE))
})

test_that("SRDT estimator matches the C reference fixtures", {
  fixtures <- srdt_fixtures()
  est <- wind_2m_liljegren(fixtures$speed, fixtures$zspeed, fixtures$solar,
    fixtures$daytime == 1L, fixtures$dt, fixtures$urban == 1L,
    diagnostics = TRUE)
  expect_identical(est$stability_class, fixtures$stability_class)
  expect_equal(est$wind_2m, fixtures$est_speed,
    tolerance = SRDT_C_TOLERANCE)
})

test_that("boundary rows just below and at each threshold match the C fixtures", {
  fixtures <- srdt_fixtures()
  boundary <- fixtures[fixtures$block == "boundary", ]
  expect_gte(nrow(boundary), 20L)
  est <- wind_2m_liljegren(boundary$speed, boundary$zspeed, boundary$solar,
    boundary$daytime == 1L, boundary$dt, boundary$urban == 1L,
    diagnostics = TRUE)
  expect_identical(est$stability_class, boundary$stability_class)
  expect_equal(est$wind_2m, boundary$est_speed,
    tolerance = SRDT_C_TOLERANCE)
})
