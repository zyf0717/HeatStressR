test_that("common contracts distinguish missing, invalid and applicability rows", {
  methods <- c("wet_bulb_stull", "wet_bulb_romps", "wbgt_simplified_abm",
    "wbgt_simplified_indoor", "humidex", "discomfort_index", "heat_index_rothfusz", "heat_index_lu")
  for (method in methods) {
    f <- getExportedValue("HeatStressR", method)
    expect_warning(result <- f(c(30, NA_real_, NaN, Inf, 30, 30),
      c(70, 70, 70, 70, -1, 101), diagnostics = TRUE), "invalid=4")
    expect_identical(is.na(result$values), c(FALSE, TRUE, TRUE, TRUE, TRUE, TRUE))
    expect_identical(result$diagnostics$rows$input_status,
      c("valid", "missing_input", rep("invalid_input", 4)))
    expect_identical(names(result), c("values", "components", "diagnostics"))
    expect_equal(nrow(result$diagnostics$rows), 6)
    expect_error(f("30", 70), "numeric vector")
    expect_error(f(1:3, 1:2), "same length")
    expect_error(f(matrix(30), 70), "numeric vector")
    expect_identical(f(numeric(), numeric()), numeric())
    expect_equal(f(c(25, 30), 70), f(c(25, 30), c(70, 70)))
    expect_no_warning(f(NA_real_, 70))
  }
  expect_warning(stull <- wet_bulb_stull(c(-21, -10, 30, 51), 50, TRUE), "outside_domain=2")
  expect_identical(stull$diagnostics$rows$domain_status, c("outside", "unknown", "within", "outside"))
  expect_true(all(is.finite(stull$values)))
  expect_error(wet_bulb_stull(30, 70, diagnostics = NA), "single logical")
})

test_that("pressure, dew-point and wind policies are explicit", {
  expect_warning(wet_bulb_romps(c(30, 30), 70, c(1010, 0)), "invalid=1")
  expect_warning(capped <- wbgt_bernard(30, 35, diagnostics = TRUE), "adjusted=1")
  expect_equal(capped$values, 30)
  expect_equal(capped$components$tpwb, 30)
  expect_true(capped$diagnostics$rows$adjusted)
  expect_warning(rejected <- wbgt_bernard(30, 35, "na", TRUE), "invalid=1")
  expect_true(is.na(rejected$values))
  expect_error(wbgt_bernard(30, 35, "error"), "exceeds")
  expect_warning(apparent_temperature(30, 70, -1), "invalid=1")
  expect_warning(effective_temperature(30, 70, Inf), "invalid=1")
  expect_warning(vapour_pressure(30, 101), "invalid=1")
  expect_warning(relative_humidity(30, 35), "adjusted=1")
})

test_that("canonical timestamps retain instants and align geographic rows", {
  utc <- as.POSIXct(c("2024-06-01 12:00:00", "2024-06-01 15:00:00"), tz = "UTC")
  iso <- c("2024-06-01T20:00:00+08:00", "2024-06-01T10:00:00-05:00")
  expect_equal(solar_zenith(utc, c(0, 20), 15), solar_zenith(iso, c(0, 20), 15), tolerance = 1e-12)
  expect_warning(x <- solar_zenith(c(iso[1], "2024-06-01"), 0, 15), "invalid=1")
  expect_true(is.na(x[2]))
  expect_no_warning(solar_zenith(as.POSIXct(NA, tz = "UTC"), 0, 15))
  expect_identical(solar_zenith(as.POSIXct(character(), tz = "UTC"), 0, 15), numeric())
})

test_that("timestamp offsets and calendar values are validated", {
  expect_warning(x <- solar_zenith(c("2024-06-01T12:00:00+08:99", "2024-02-30T12:00:00Z"),0,15),"invalid=2")
  expect_true(all(is.na(x)))
})

test_that("unsupported conversion extremes return NA rather than non-finite output", {
  expect_warning(x <- vapour_pressure(-245.53,100),"solver_failure=1")
  expect_true(is.na(x))
  expect_warning(x <- relative_humidity(-245.52,-246),"solver_failure=1")
  expect_true(is.na(x))
})

test_that("POSIXlt zones are converted as instants rather than reinterpreted", {
  utc <- as.POSIXct(c("2024-06-01 12:00:00","2024-06-01 20:00:00"),tz="UTC")
  local <- as.POSIXlt(utc,tz="Asia/Singapore")
  expect_equal(as.numeric(HeatStressR:::.normalise_time(local)),as.numeric(utc))
  expect_equal(solar_zenith(local,0,15),solar_zenith(utc,0,15),tolerance=1e-12)
  expect_equal(wbgt_liljegren(30,20,1,700,local,0,15),
    wbgt_liljegren(30,20,1,700,utc,0,15),tolerance=1e-10)
})
