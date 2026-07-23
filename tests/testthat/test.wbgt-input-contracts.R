wbgt_valid_args <- function() {
  list(tas = 20, dewp = 10, wind = 1, radiation = 0,
    dates = as.POSIXct("2024-06-01", tz = "UTC"), lon = 0, lat = 0)
}

test_that("wbgt.Liljegren rejects malformed wrapper controls", {
  args <- wbgt_valid_args()
  for (name in c("hour", "noNAs", "swap", "diagnostics")) {
    expect_error(do.call(wbgt.Liljegren, c(args, setNames(list(c(TRUE, FALSE)), name))),
      "single logical")
    expect_error(do.call(wbgt.Liljegren, c(args, setNames(list(1), name))),
      "single logical")
  }
  expect_error(do.call(wbgt.Liljegren, c(args, list(engine = "invalid"))), "should be one of")
  expect_error(do.call(wbgt.Liljegren, c(args, list(solar_time = "invalid"))),
    "solar_time")
  expect_error(do.call(wbgt.Liljegren, c(args, list(hour = FALSE,
    solar_time = "timestamp"))), "conflicting")
  invalid <- args; invalid$lon <- c(0, 1, 2)
  expect_error(do.call(wbgt.Liljegren, invalid), "meteorological input length")
  invalid <- args; invalid$lat <- c(0, 1, 2)
  expect_error(do.call(wbgt.Liljegren, invalid), "meteorological input length")
  invalid <- args; invalid$lon <- Inf
  expect_error(do.call(wbgt.Liljegren, invalid), "one finite")
  invalid <- args; invalid$lat <- NaN
  expect_error(do.call(wbgt.Liljegren, invalid), "one finite")
  invalid <- args; invalid$pressure <- c(1000, 900)
  expect_error(do.call(wbgt.Liljegren, invalid), "pressure")
  invalid <- args; invalid$pressure <- 0
  expect_error(do.call(wbgt.Liljegren, invalid), "pressure")
  invalid <- args; invalid$surface_albedo <- 1.1
  expect_error(do.call(wbgt.Liljegren, invalid), "surface_albedo")
  invalid <- args; invalid$globe_diameter <- 0
  expect_error(do.call(wbgt.Liljegren, invalid), "globe_diameter")
  invalid <- args; invalid$min_wind_speed <- -0.01
  expect_error(do.call(wbgt.Liljegren, invalid), "min_wind_speed")
  invalid <- args; invalid$direct_fraction <- 1.1
  expect_error(do.call(wbgt.Liljegren, invalid), "direct_fraction")
  invalid <- args; invalid$direct_fraction <- c(0.2, 0.8)
  expect_error(do.call(wbgt.Liljegren, invalid), "direct_fraction")
})

test_that("wbgt.Liljegren supports row-aligned direct fractions", {
  args <- list(
    tas = c(25, 30, 35), dewp = c(15, 20, 25), wind = c(0.2, 1, 2),
    radiation = c(200, 600, 900),
    dates = as.POSIXct("2024-06-01 10:00:00", tz = "UTC") + 0:2 * 3600,
    lon = 0, lat = 20, hour = TRUE, direct_fraction = c(0.2, 0.5, 0.8)
  )
  scalar <- suppressWarnings(do.call(wbgt.Liljegren, c(args, list(engine = "scalar"))))
  batch <- suppressWarnings(do.call(wbgt.Liljegren, c(args, list(engine = "batch"))))
  for (component in c("data", "Tg", "Tnwb")) {
    expect_identical(is.na(batch[[component]]), is.na(scalar[[component]]))
    expect_equal(batch[[component]], scalar[[component]], tolerance = 1e-4)
  }
  default <- suppressWarnings(do.call(wbgt.Liljegren,
    c(args[names(args) != "direct_fraction"], list(engine = "batch"))))
  expect_false(isTRUE(all.equal(batch$data, default$data, tolerance = 1e-8)))
})

test_that("wbgt.Liljegren supports row-aligned pressure", {
  args <- list(
    tas = c(25, 30, 35), dewp = c(15, 20, 25), wind = c(0.2, 1, 2),
    radiation = c(200, 600, 900),
    dates = as.POSIXct("2024-06-01 10:00:00", tz = "UTC") + 0:2 * 3600,
    lon = 0, lat = 20, hour = TRUE, pressure = c(700, 850, 1010)
  )
  scalar <- suppressWarnings(do.call(wbgt.Liljegren, c(args, list(engine = "scalar"))))
  batch <- suppressWarnings(do.call(wbgt.Liljegren, c(args, list(engine = "batch"))))
  for (component in c("data", "Tg", "Tnwb")) {
    expect_identical(is.na(batch[[component]]), is.na(scalar[[component]]))
    expect_equal(batch[[component]], scalar[[component]], tolerance = 1e-4)
  }

  missing_args <- args
  missing_args$pressure <- c(700, NA_real_, 1010)
  missing <- suppressWarnings(do.call(wbgt.Liljegren,
    c(missing_args, list(diagnostics = TRUE))))
  expect_identical(missing$diagnostics$input_status[2], "missing_input")
  expect_false(missing$diagnostics$attempted[2])
})

test_that("wbgt.Liljegren accepts ISO 8601 instants", {
  args <- list(
    tas = c(25, 30), dewp = c(15, 20), wind = c(0.5, 1),
    radiation = c(500, 700), lon = 0, lat = 20, hour = TRUE
  )
  utc <- as.POSIXct(c("2024-06-01 12:00:00", "2024-06-01 15:00:00"), tz = "UTC")
  iso8601 <- c("2024-06-01T20:00:00+08:00", "2024-06-01T10:00:00-05:00")
  utc_result <- suppressWarnings(do.call(wbgt.Liljegren, c(args, list(dates = utc))))
  iso_result <- suppressWarnings(do.call(wbgt.Liljegren, c(args, list(dates = iso8601))))

  for (component in c("data", "Tg", "Tnwb")) {
    expect_equal(iso_result[[component]], utc_result[[component]], tolerance = 1e-12)
  }
})

test_that("wbgt.Liljegren solar_time aliases the legacy hour selector", {
  args <- list(
    tas = c(25, 30), dewp = c(15, 20), wind = c(0.5, 1),
    radiation = c(500, 700),
    dates = as.POSIXct(c("2024-06-01 12:00:00", "2024-06-01 15:00:00"), tz = "UTC"),
    lon = 0, lat = 20
  )
  timestamp <- suppressWarnings(do.call(wbgt.Liljegren,
    c(args, list(solar_time = "timestamp"))))
  legacy <- suppressWarnings(do.call(wbgt.Liljegren,
    c(args, list(hour = TRUE))))
  for (component in c("data", "Tg", "Tnwb")) {
    expect_equal(timestamp[[component]], legacy[[component]], tolerance = 0)
  }
})

test_that("wbgt.Liljegren requires non-empty aligned meteorological inputs", {
  args <- wbgt_valid_args()
  expect_error(wbgt.Liljegren(c(20, 21), 10, c(1, 1), c(0, 0),
    args$dates, args$lon, args$lat), "same length")
  expect_error(wbgt.Liljegren(numeric(), numeric(), numeric(), numeric(),
    as.POSIXct(character(), tz = "UTC"), 0, 0), "must not be empty")
  expect_error(wbgt.Liljegren(20, 10, 1, 0,
    as.POSIXct(c("2024-06-01", "2024-06-02"), tz = "UTC"), 0, 0), "dates")
})

test_that("dewpoint policies are explicit for each noNAs and swap combination", {
  args <- wbgt_valid_args()
  args$tas <- rep(20, 3)
  args$dewp <- c(20, 20 + 5e-5, 20 + 2e-4)
  args$wind <- rep(1, 3)
  args$radiation <- rep(0, 3)
  args$dates <- as.POSIXct("2024-06-01", tz = "UTC") + 0:2 * 3600
  for (noNAs in c(TRUE, FALSE)) for (swap in c(TRUE, FALSE)) {
    result <- suppressWarnings(do.call(wbgt.Liljegren,
      c(args, list(noNAs = noNAs, swap = swap, diagnostics = TRUE))))
    if (noNAs) {
      expect_true(all(result$diagnostics$attempted))
      expect_true(all(result$diagnostics$input_status == "attempted"))
    } else {
      expect_identical(result$diagnostics$attempted, c(TRUE, FALSE, FALSE))
      expect_identical(result$diagnostics$input_status,
        c("attempted", "invalid_dewpoint", "invalid_dewpoint"))
    }
  }
})
