####################################################################
#
# Baseline fixtures for solar zenith calculation.
#
# Covers supported date forms, calendar boundaries, UTC hours, and
# geographic locations for the later vectorization equivalence test.
#
####################################################################

cal_zenith_reference_cases <- list(
  list(
    dates = as.Date(c("2019-01-01", "2020-02-29", "2020-12-31", "2021-01-01")),
    lon = 0,
    lat = 0,
    hour = FALSE
  ),
  list(
    dates = c("2019-06-21", "2020-02-29", "2020-12-31", "2021-06-21"),
    lon = -5.66,
    lat = 40.96,
    hour = FALSE
  ),
  list(
    dates = as.POSIXct(
      c("2020-02-29 00:00:00", "2020-02-29 12:00:00",
        "2020-12-31 23:00:00", "2021-01-01 00:00:00"),
      tz = "UTC"
    ),
    lon = 151.21,
    lat = -33.87,
    hour = TRUE
  ),
  list(
    dates = c(
      "2020-02-29 00:00:00", "2020-02-29 12:00:00",
      "2020-12-31 23:00:00", "2021-01-01 00:00:00"
    ),
    lon = -5.66,
    lat = 40.96,
    hour = TRUE
  ),
  list(
    # These timestamps must be normalized to UTC before extracting hours.
    dates = as.POSIXct(
      c("2020-02-28 19:00:00", "2020-02-29 07:00:00"),
      tz = "America/New_York"
    ),
    lon = -5.66,
    lat = 40.96,
    hour = TRUE
  )
)

test_that("vector calZenith matches the preserved reference fixtures", {
  for (case in cal_zenith_reference_cases) {
    expected <- vapply(
      seq_along(case$dates),
      function(i) {
        reference_calZenith_scalar(
          case$dates[i], case$lon, case$lat, hour = case$hour
        )
      },
      numeric(1)
    )
    actual <- calZenith(case$dates, case$lon, case$lat, hour = case$hour)

    expect_length(actual, length(case$dates))
    expect_equal(actual, expected, tolerance = 1e-12)
  }
})

test_that("vector calZenith preserves missing dates and rejects coordinate recycling", {
  dates <- as.Date(c("2020-02-29", NA, "2020-12-31", "2021-01-01"))
  valid <- which(!is.na(dates))
  result <- calZenith(dates, lon = -5.66, lat = 40.96)
  expected <- vapply(
    valid,
    function(i) reference_calZenith_scalar(dates[i], -5.66, 40.96, hour = TRUE),
    numeric(1)
  )

  expect_length(result, length(dates))
  expect_identical(is.na(result), is.na(dates))
  expect_equal(result[valid], expected, tolerance = 1e-12)
  expect_error(calZenith(dates, lon = c(-5.66, 0), lat = 40.96), "lon")
  expect_error(calZenith(dates, lon = -5.66, lat = c(40.96, 0)), "lat")
  expect_error(calZenith(dates, lon = 181, lat = 40.96), "Invalid lon")
  expect_error(calZenith(dates, lon = -5.66, lat = 91), "Invalid lat")
  expect_error(calZenith(dates, lon = -5.66, lat = 40.96, hour = NA), "hour")
})

test_that("calZenith applies longitude and preserves UTC instants", {
  instant <- as.POSIXct("2024-03-20 12:00:00", tz = "UTC")
  # Longitude is scalar by contract; calculate the three locations separately.
  zenith <- vapply(c(-90, 0, 90), function(lon) {
    calZenith(instant, lon = lon, lat = 0, hour = TRUE)
  }, numeric(1))
  expect_equal(zenith, c(91.98110, 1.986861, 88.01890), tolerance = 1e-5)
  expect_true(all(zenith[2] < zenith[c(1, 3)]))

  new_york <- as.POSIXct("2024-03-20 08:00:00", tz = "America/New_York")
  expect_equal(calZenith(new_york, lon = 0, lat = 0, hour = TRUE), zenith[2],
    tolerance = 1e-12)

})

test_that("solar_time is a clear alias for the legacy hour selector", {
  instant <- as.POSIXct("2024-03-20 12:00:00", tz = "UTC")
  expect_equal(
    calZenith(instant, lon = 0, lat = 0),
    calZenith(instant, lon = 0, lat = 0, solar_time = "timestamp"), tolerance = 0
  )
  expect_equal(
    calZenith(instant, lon = 0, lat = 0, solar_time = "timestamp"),
    calZenith(instant, lon = 0, lat = 0, hour = TRUE), tolerance = 0
  )
  expect_equal(
    calZenith(instant, lon = 0, lat = 0, solar_time = "date_noon"),
    calZenith(instant, lon = 0, lat = 0, hour = FALSE), tolerance = 0
  )
  expect_error(calZenith(instant, lon = 0, lat = 0, solar_time = "invalid"),
    "solar_time")
  expect_error(calZenith(instant, lon = 0, lat = 0, hour = FALSE,
    solar_time = "timestamp"), "conflicting")
})

test_that("calZenith accepts offset-aware timestamps and ISO 8601 instants", {
  utc <- as.POSIXct(c("2024-03-20 12:00:00", "2024-03-20 15:30:00"), tz = "UTC")
  offset_posix <- as.POSIXct(c("2024-03-20 20:00:00", "2024-03-20 23:30:00"),
    tz = "Etc/GMT-8")
  iso8601 <- c("2024-03-20T07:00:00-05:00", "2024-03-20T15:30:00Z")
  expected <- calZenith(utc, lon = 0, lat = 0, hour = TRUE)

  expect_equal(calZenith(offset_posix, lon = 0, lat = 0, hour = TRUE), expected,
    tolerance = 1e-12)
  expect_equal(calZenith(iso8601, lon = 0, lat = 0, hour = TRUE), expected,
    tolerance = 1e-12)
})
