reference_liljegren_zenith_rows <- function(dates, lon, lat, hour) {
  n <- length(dates)
  lon <- rep(lon, length.out = n)
  lat <- rep(lat, length.out = n)
  vapply(seq_len(n), function(i) {
    HeatStressR:::degToRad(calZenith(dates[i], lon[i], lat[i], hour = hour))
  }, numeric(1))
}

test_that("vectorized Liljegren geometry preserves row-wise reference results", {
  hourly <- as.POSIXct("2024-03-20 00:00:00", tz = "UTC") + 3600 * 0:47
  repeated <- rep(as.POSIXct(c("2024-06-20 05:55:00", "2024-06-20 12:00:00",
    "2024-06-20 18:05:00"), tz = "UTC"), each = 3)
  cases <- list(
    fixed_coordinate = list(
      dates = hourly, lon = -5.66, lat = 40.96
    ),
    repeated_timestamps = list(
      dates = repeated, lon = seq(-160, 160, length.out = 9),
      lat = seq(-70, 70, length.out = 9)
    ),
    repeated_coordinates = list(
      dates = hourly[1:12], lon = rep(c(-90, 0, 90), each = 4),
      lat = rep(c(-45, 0, 45), each = 4)
    ),
    unique_coordinates = list(
      dates = rep(hourly[1:4], 3), lon = seq(-179, 179, length.out = 12),
      lat = seq(-89, 89, length.out = 12)
    ),
    mixed_cardinality = list(
      dates = rep(hourly[1:6], 2),
      lon = c(rep(-5.66, 5), rep(120, 3), -179, -30, 45, 179),
      lat = c(rep(40.96, 5), rep(-20, 3), -80, -15, 35, 80)
    ),
    posixct = list(
      dates = as.POSIXct(c("2024-01-01 00:00:00", "2024-07-01 12:00:00"),
        tz = "UTC"), lon = c(-30, 75), lat = c(20, -35)
    ),
    iso8601_offsets = list(
      dates = c("2024-03-20T12:00:00Z", "2024-03-20T20:00:00+08:00",
        "2024-03-20T07:00:00-0500"),
      lon = c(0, 45, -90), lat = c(0, 15, -30)
    ),
    missing_dates = list(
      dates = as.POSIXct(c("2024-06-20 06:00:00", NA,
        "2024-06-20 18:00:00"), tz = "UTC"),
      lon = c(-5, 0, 5), lat = c(40, 0, -40)
    ),
    day_night_transition = list(
      dates = as.POSIXct(c("2024-03-20 05:50:00", "2024-03-20 06:00:00",
        "2024-03-20 06:10:00", "2024-03-20 17:50:00",
        "2024-03-20 18:00:00", "2024-03-20 18:10:00"), tz = "UTC"),
      lon = 0, lat = 0
    ),
    antimeridian = list(
      dates = hourly[1:4], lon = c(-180, -179.999999, 179.999999, 180),
      lat = c(-45, 0, 45, 80)
    ),
    near_poles = list(
      dates = hourly[1:4], lon = c(-120, -30, 30, 120),
      lat = c(-90, -89.999999, 89.999999, 90)
    )
  )

  for (case_name in names(cases)) {
    case <- cases[[case_name]]
    expected <- reference_liljegren_zenith_rows(
      case$dates, case$lon, case$lat, hour = TRUE
    )
    actual <- HeatStressR:::calculate_liljegren_zenith(
      case$dates, case$lon, case$lat, hour = TRUE
    )
    expect_length(actual, length(case$dates))
    expect_identical(is.na(actual), is.na(expected), info = case_name)
    expect_equal(actual, expected, tolerance = 1e-14, info = case_name)
  }
})

test_that("Liljegren engines preserve outputs across coordinate cardinalities", {
  n <- 12L
  dates <- rep(as.POSIXct(c("2024-06-20 00:00:00", "2024-06-20 06:00:00",
    "2024-06-20 12:00:00", "2024-06-20 18:00:00"), tz = "UTC"), 3)
  input <- list(
    tas = seq(22, 33, length.out = n),
    dewp = seq(14, 22, length.out = n),
    wind = rep(c(0.05, 0.2, 1, 2), 3),
    radiation = rep(c(0, 250, 800, 20), 3), dates = dates
  )
  coordinates <- list(
    fixed = list(lon = -5.66, lat = 40.96),
    repeated = list(lon = rep(c(-5.66, 120), each = 6),
      lat = rep(c(40.96, -20), each = 6)),
    unique = list(lon = seq(-179, 179, length.out = n),
      lat = seq(-80, 80, length.out = n))
  )
  run <- function(engine, diagnostics, coordinate) suppressWarnings(wbgt.Liljegren(
    input$tas, input$dewp, input$wind, input$radiation, input$dates,
    lon = coordinate$lon, lat = coordinate$lat, hour = TRUE,
    engine = engine, diagnostics = diagnostics, workers = 1L
  ))

  for (case_name in names(coordinates)) {
    coordinate <- coordinates[[case_name]]
    batch <- run("batch", TRUE, coordinate)
    batch_compact <- run("batch", FALSE, coordinate)
    scalar <- run("scalar", TRUE, coordinate)
    for (component in c("data", "Tg", "Tnwb")) {
      expect_identical(batch_compact[[component]], batch[[component]], info = case_name)
      expect_identical(is.na(batch[[component]]), is.na(scalar[[component]]),
        info = case_name)
      expect_equal(batch[[component]], scalar[[component]], tolerance = 1e-4,
        info = case_name)
    }
    expect_identical(batch$diagnostics$input_status,
      scalar$diagnostics$input_status, info = case_name)
    expect_identical(batch$diagnostics$attempted,
      scalar$diagnostics$attempted, info = case_name)
    for (field in c("wind_clamped", "radiation_clamped",
      "radiation_zeroed_below_horizon", "dewpoint_adjusted")) {
      expect_identical(batch$diagnostics[[field]], scalar$diagnostics[[field]],
        info = paste(case_name, field))
    }
  }
})
