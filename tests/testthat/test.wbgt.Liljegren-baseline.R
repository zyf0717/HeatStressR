####################################################################
#
# End-to-end Liljegren baseline fixture.
#
# Guards output values, NA positions, and row alignment against the
# preserved scalar-zenith reference implementation.
#
####################################################################

context("Liljegren scalar-zenith baseline")

liljegren_baseline_fixture <- local({
  dates <- c(
    seq(as.POSIXct("2020-02-28 00:00:00", tz = "UTC"), by = "hour", length.out = 12),
    seq(as.POSIXct("2021-06-21 00:00:00", tz = "UTC"), by = "hour", length.out = 12)
  )
  tas <- rep(c(17, 18, 20, 23, 26, 28, 30, 31, 29, 25, 21, 18), 2)
  dewp <- rep(c(17, 16, 17, 18, 20, 22, 24, 25, 23, 20, 18, 17), 2)
  wind <- rep(c(0, 0.05, 0.2, 0.8, 1.5, 2.5), 4)
  radiation <- rep(c(0, 0, 25, 180, 450, 700, 850, 600, 250, 40, 0, 0), 2)

  # Missing meteorological inputs must retain their output row positions.
  tas[5] <- NA_real_
  dewp[16] <- NA_real_
  wind[22] <- NA_real_

  list(
    tas = tas,
    dewp = dewp,
    wind = wind,
    radiation = radiation,
    dates = dates,
    lon = -5.66,
    lat = 40.96,
    hour = TRUE
  )
})

test_that("Liljegren preserves the scalar-zenith baseline and row alignment", {
  fixture <- liljegren_baseline_fixture
  # This is the old per-row zenith calculation used as the end-to-end oracle.
  expected <- reference_wbgt.Liljegren_scalar_zenith(
    fixture$tas, fixture$dewp, fixture$wind, fixture$radiation,
    fixture$dates, fixture$lon, fixture$lat, hour = fixture$hour
  )
  actual <- wbgt.Liljegren(
    fixture$tas, fixture$dewp, fixture$wind, fixture$radiation,
    fixture$dates, fixture$lon, fixture$lat, hour = fixture$hour
  )

  for (component in c("data", "Tnwb", "Tg")) {
    expect_length(actual[[component]], length(fixture$tas))
    comparable <- !is.na(actual[[component]]) & !is.na(expected[[component]])
    expect_equal(actual[[component]][comparable], expected[[component]][comparable],
      tolerance = 2e-4)
  }

  expected_missing <- is.na(fixture$tas) | is.na(fixture$dewp) |
    is.na(fixture$wind) | is.na(fixture$radiation)
  expect_true(all(is.na(actual$Tnwb)[expected_missing]))
  expect_identical(is.na(actual$data), is.na(actual$Tg) | is.na(actual$Tnwb))
})

test_that("Liljegren requires dates to align with meteorological inputs", {
  fixture <- liljegren_baseline_fixture

  expect_error(
    wbgt.Liljegren(
      fixture$tas, fixture$dewp, fixture$wind, fixture$radiation,
      fixture$dates[1], fixture$lon, fixture$lat, hour = fixture$hour
    ),
    "dates"
  )
  expect_error(
    wbgt.Liljegren(
      fixture$tas, fixture$dewp, fixture$wind, fixture$radiation,
      fixture$dates[-1], fixture$lon, fixture$lat, hour = fixture$hour
    ),
    "dates"
  )
})

test_that("Liljegren preserves missing date row positions", {
  fixture <- liljegren_baseline_fixture
  fixture$dates[1] <- as.POSIXct(NA, tz = "UTC")
  expected_missing <- is.na(fixture$tas) | is.na(fixture$dewp) |
    is.na(fixture$wind) | is.na(fixture$radiation) | is.na(fixture$dates)

  actual <- wbgt.Liljegren(
    fixture$tas, fixture$dewp, fixture$wind, fixture$radiation,
    fixture$dates, fixture$lon, fixture$lat, hour = fixture$hour
  )

  expect_true(all(is.na(actual$Tnwb)[expected_missing]))
  expect_identical(is.na(actual$data), is.na(actual$Tg) | is.na(actual$Tnwb))
})
