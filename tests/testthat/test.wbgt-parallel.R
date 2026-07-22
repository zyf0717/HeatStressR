context("Liljegren parallel batch execution")

parallel_fixture <- function() {
  list(
    tas = c(20, 35, 30, NA_real_, 25),
    dewp = c(15, 20, 29, 10, 5),
    wind = c(0, 0.1, 5, 1, 0.05),
    radiation = c(0, 1000, 900, 200, 0),
    dates = as.POSIXct("2020-02-28 00:00:00", tz = "UTC") + 3600 * 0:4
  )
}

run_parallel_fixture <- function(workers) {
  x <- parallel_fixture()
  suppressWarnings(wbgt.Liljegren(
    x$tas, x$dewp, x$wind, x$radiation, x$dates,
    lon = -5.66, lat = 40.96, hour = TRUE, engine = "batch",
    workers = workers, diagnostics = TRUE
  ))
}

test_that("workers are validated and restricted to the batch engine", {
  x <- parallel_fixture()
  args <- list(x$tas, x$dewp, x$wind, x$radiation, x$dates,
    lon = -5.66, lat = 40.96, hour = TRUE, engine = "batch")
  for (workers in list(0, -1, 1.5, NA_real_, Inf, "2", NULL)) {
    expect_error(do.call(wbgt.Liljegren, c(args, list(workers = workers))), "workers")
  }
  expect_error(HeatStressR:::validate_workers(), "workers")
  args$engine <- "scalar"
  expect_error(do.call(wbgt.Liljegren, c(args, list(workers = 2))),
    "requires engine")
  expect_error(HeatStressR:::validate_workers(HeatStressR:::max_liljegren_workers() + 1L),
    "permitted worker count")
})

test_that("check core limit constrains the permitted worker maximum", {
  key <- "_R_CHECK_LIMIT_CORES_"
  previous <- Sys.getenv(key, unset = NA_character_)
  on.exit({
    if (is.na(previous)) Sys.unsetenv(key) else Sys.setenv(`_R_CHECK_LIMIT_CORES_` = previous)
  }, add = TRUE)

  Sys.setenv(`_R_CHECK_LIMIT_CORES_` = "false")
  unrestricted <- HeatStressR:::max_liljegren_workers()
  Sys.setenv(`_R_CHECK_LIMIT_CORES_` = "true")
  limited <- HeatStressR:::max_liljegren_workers()

  expect_lte(limited, 2L)
  expect_identical(limited, min(unrestricted, 2L))
  expect_error(HeatStressR:::validate_workers(limited + 1L),
    "permitted worker count")
})

test_that("parallel batch execution preserves results and diagnostics", {
  skip_if(HeatStressR:::max_liljegren_workers() < 2L,
    "requires at least two logical CPUs")
  sequential <- run_parallel_fixture(1L)
  parallel <- run_parallel_fixture(2L)
  expect_identical(sequential$diagnostics$workers, 1L)
  expect_identical(parallel$diagnostics$workers, 2L)
  expect_identical(sequential$diagnostics$requested_workers, 1L)
  expect_identical(parallel$diagnostics$requested_workers, 2L)
  parallel$diagnostics$workers <- 1L
  parallel$diagnostics$requested_workers <- 1L
  expect_identical(parallel, sequential)
})

test_that("parallel batch execution supports row-aligned coordinates", {
  skip_if(HeatStressR:::max_liljegren_workers() < 2L,
    "requires at least two logical CPUs")
  x <- parallel_fixture()
  lon <- c(-5.66, 0, -5.66, 0, -5.66)
  lat <- c(40.96, 15, 40.96, 15, 40.96)
  run <- function(workers) suppressWarnings(wbgt.Liljegren(
    x$tas, x$dewp, x$wind, x$radiation, x$dates,
    lon = lon, lat = lat, hour = TRUE, engine = "batch", workers = workers,
    diagnostics = TRUE
  ))
  sequential <- run(1L)
  parallel <- run(2L)
  parallel$diagnostics$workers <- 1L
  parallel$diagnostics$requested_workers <- 1L
  expect_identical(parallel, sequential)
})

test_that("parallel chunks reproduce row-local preprocessing", {
  skip_if(HeatStressR:::max_liljegren_workers() < 2L,
    "requires at least two logical CPUs")
  x <- parallel_fixture()
  x$dewp[2] <- 40
  x$dates[5] <- NA
  run <- function(workers) suppressWarnings(wbgt.Liljegren(
    x$tas, x$dewp, x$wind, x$radiation, x$dates,
    lon = -5.66, lat = 40.96, hour = TRUE, engine = "batch",
    workers = workers, diagnostics = TRUE, noNAs = FALSE,
    pressure = c(1010, 1005, 1000, 995, 990)
  ))
  sequential <- run(1L)
  parallel <- run(2L)
  expect_identical(parallel$diagnostics$input_status[2], "invalid_dewpoint")
  expect_identical(parallel$diagnostics$input_status[5], "missing_date")
  parallel$diagnostics$workers <- 1L
  parallel$diagnostics$requested_workers <- 1L
  expect_identical(parallel, sequential)
})

test_that("single-row batch execution caps workers at the input size", {
  skip_if(HeatStressR:::max_liljegren_workers() < 2L,
    "requires at least two logical CPUs")
  x <- parallel_fixture()
  one <- suppressWarnings(wbgt.Liljegren(
    x$tas[1], x$dewp[1], x$wind[1], x$radiation[1], x$dates[1],
    lon = -5.66, lat = 40.96, hour = TRUE, engine = "batch",
    workers = 2L, diagnostics = TRUE
  ))
  expect_identical(one$diagnostics$workers, 1L)
  expect_identical(one$diagnostics$requested_workers, 2L)
})
