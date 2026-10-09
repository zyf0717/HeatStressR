test_that("legacy public argument lists remain leading signature prefixes", {
  legacy_formals <- list(
    apparentTemp = c("tas", "hurs", "wind"),
    calZenith = c("dates", "lon", "lat", "hour"),
    dewp2hurs = c("tas", "dewp"),
    discomInd = c("tas", "hurs"),
    effectiveTemp = c("tas", "hurs", "wind"),
    fTg = c("tas", "relh", "Pair", "wind", "min.speed", "radiation",
      "propDirect", "zenith", "SurfAlbedo", "tolerance"),
    fTnwb = c("tas", "dewp", "relh", "Pair", "wind", "min.speed",
      "radiation", "propDirect", "zenith", "irad", "SurfAlbedo", "tolerance"),
    hi = c("tas", "hurs"),
    humidex = c("tas", "hurs"),
    indexShow = NULL,
    swbgt = c("tas", "hurs"),
    tashurs2vap.pres = c("tas", "hurs"),
    wbgt.Bernard = c("tas", "dewp", "tolerance", "noNAs", "swap"),
    wbgt.Liljegren = c("tas", "dewp", "wind", "radiation", "dates", "lon",
      "lat", "tolerance", "noNAs", "swap", "hour"),
    wbt.Stull = c("tas", "hurs")
  )

  for (name in names(legacy_formals)) {
    expected <- legacy_formals[[name]]
    actual <- names(formals(getExportedValue("HeatStressR", name)))
    expect_identical(head(actual, length(expected)), expected, info = name)
  }
})

test_that("legacy positional Liljegren and solver calls remain accepted", {
  expect_length(calZenith("1981-06-15", -5.66, 40.96, FALSE), 1L)
  expect_length(suppressWarnings(fTg(30, 50, 1010, 1, 0.13, 700, 0.8, 0.5, 0.4, 1e-4)), 1L)
  expect_length(suppressWarnings(fTnwb(30, 20, dewp2hurs(30, 20), 1010, 1, 0.13, 700,
    0.8, 0.5, 1, 0.4, 1e-4)), 1L)

  result <- suppressWarnings(wbgt.Liljegren(
    30, 20, 1, 700, "2024-06-01 12:00:00", 0, 15,
    1e-4, TRUE, FALSE, TRUE
  ))
  expect_identical(names(result), c("data", "Tnwb", "Tg"))
  expect_true(all(vapply(result, length, integer(1)) == 1L))
})

test_that("deprecated endpoints warn once per session and name their replacements", {
  seen <- HeatStressR:::.deprecation_seen
  saved <- as.list(seen)
  rm(list = ls(seen), envir = seen)
  on.exit({
    rm(list = ls(seen), envir = seen)
    list2env(saved, seen)
  }, add = TRUE)
  calls <- list(
    apparentTemp = function() apparentTemp(30,70,2),
    effectiveTemp = function() effectiveTemp(30,70,2),
    discomInd = function() discomInd(30,70), hi = function() hi(30,70),
    swbgt = function() swbgt(30,70), wbt.Stull = function() wbt.Stull(30,70),
    dewp2hurs = function() dewp2hurs(30,20),
    tashurs2vap.pres = function() tashurs2vap.pres(30,70),
    wbgt.Bernard = function() wbgt.Bernard(30,20),
    wbgt.Liljegren = function() wbgt.Liljegren(30,20,1,700,"2024-06-01 12:00:00",0,15),
    calZenith = function() calZenith("2024-06-01",0,15),
    indexShow = function() indexShow(),
    fTg = function() fTg(30,50,1010,1,0.13,700,0.8,0.5),
    fTnwb = function() fTnwb(30,20,50,1010,1,0.13,700,0.8,0.5))
  expect_setequal(names(calls), names(HeatStressR:::.legacy_endpoints))
  for (name in names(calls)) {
    warnings <- list()
    withCallingHandlers(calls[[name]](), warning = function(w) {
      warnings[[length(warnings)+1L]] <<- w
      invokeRestart("muffleWarning")
    })
    expect_length(warnings, 1L)
    expect_s3_class(warnings[[1]], "heatstressr_deprecation")
    expect_true(grepl(HeatStressR:::.legacy_endpoints[[name]], conditionMessage(warnings[[1]]), fixed = TRUE))
    expect_no_warning(calls[[name]]())
  }
})

test_that("legacy bulk aliases preserve requested labels and resolve duplicates", {
  x <- suppressWarnings(heat_indices(30,70,indices=c("hi","swbgt")))
  expect_identical(names(x),c("hi","swbgt"))
  expect_equal(x$hi,heat_index_rothfusz(30,70))
  expect_equal(x$swbgt,wbgt_simplified_indoor(30,70))
  expect_error(suppressWarnings(heat_indices(30,70,indices=c("hi","heat_index_rothfusz"))),"unique")
  expect_equal(suppressWarnings(heat_indices(30,70,wind=2)),heat_indices(30,70,wind_10m=2))
  expect_error(suppressWarnings(heat_indices(30,70,wind=2,wind_10m=3)),"conflict")
})

test_that("legacy Bernard policy maps to canonical cap/reject/swap", {
  tas <- c(30, 30, 30, 30, NA_real_, 30, 30)
  dewp <- c(20, 30, 35, 30.00005, 20, NA_real_, 10)
  for (noNAs in c(TRUE, FALSE)) for (swap in c(TRUE, FALSE)) {
    adjusted_tas <- if (noNAs && swap) pmax(tas, dewp) else tas
    adjusted_dewp <- if (noNAs && swap) pmin(tas, dewp) else dewp
    expected <- suppressWarnings(wbgt_bernard(adjusted_tas, adjusted_dewp,
      if (noNAs) "cap" else "na", diagnostics = TRUE))
    actual <- suppressWarnings(wbgt.Bernard(tas, dewp, noNAs = noNAs, swap = swap))
    expect_equal(actual$Tpwb, expected$components$tpwb)
    expect_equal(actual$data, expected$values)
    if (!noNAs) expect_true(is.na(actual$data[4]))
  }
})

test_that("legacy swapping validates input types and lengths before transformation", {
  local_mocked_bindings(.warn_deprecation = function(...) NULL, .package = "HeatStressR")
  for (swap in c(FALSE, TRUE)) {
    expect_error(wbgt.Bernard(c(30, 40), c(10, 20, 25, 30), swap = swap), "same length")
    expect_error(wbgt.Bernard(30, matrix(20), swap = swap), "numeric vector")
    expect_error(wbgt.Bernard(30, "20", swap = swap), "numeric vector")
    expect_error(wbgt.Liljegren(30, matrix(20), 1, 700,
      "2024-06-01T12:00:00Z", 0, 15, swap = swap), "numeric vector")
  }
  expanded <- wbgt.Bernard(30, c(20, 35), swap = TRUE)
  expected <- wbgt_bernard(c(30, 35), c(20, 30), diagnostics = TRUE)
  expect_equal(expanded$data, expected$values)
  expect_equal(expanded$Tpwb, expected$components$tpwb)
})

test_that("legacy timestamps distinguish parsing failures from missing dates", {
  local_mocked_bindings(.warn_deprecation = function(...) NULL, .package = "HeatStressR")
  for (hour in c(FALSE, TRUE)) {
    dates <- c("2024-06-01T12:00:00Z", NA_character_, "garbage", "2024-02-30T12:00:00Z")
    expect_warning(zenith <- calZenith(dates, 0, 15, hour = hour), "invalid=2")
    expect_identical(is.na(zenith), c(FALSE, TRUE, TRUE, TRUE))
    expect_warning(result <- wbgt.Liljegren(rep(30, 4), rep(20, 4), rep(1, 4),
      rep(700, 4), dates, 0, 15, hour = hour, diagnostics = TRUE), "invalid=2")
    expect_identical(result$diagnostics$input_status,
      c("attempted", "missing_date", "invalid_input", "invalid_input"))
    expect_identical(result$diagnostics$attempted, c(TRUE, FALSE, FALSE, FALSE))
    expect_identical(is.na(result$data), c(FALSE, TRUE, TRUE, TRUE))
    expect_no_warning(calZenith(NA_character_, 0, 15, hour = hour))
    instants <- as.POSIXct(c(1717243200, NA_real_, NaN), origin = "1970-01-01", tz = "UTC")
    expect_warning(x <- calZenith(instants, 0, 15, hour = hour), "invalid=1")
    expect_identical(is.na(x), c(FALSE, TRUE, TRUE))
  }
})

test_that("legacy timestamp and date-noon modes preserve POSIXlt instants", {
  utc <- as.POSIXct(c("2024-06-01 12:00:00","2024-06-01 20:00:00"),tz="UTC")
  local <- as.POSIXlt(utc,tz="Asia/Singapore")
  expect_equal(suppressWarnings(calZenith(local,0,15,hour=TRUE)),
    suppressWarnings(calZenith(utc,0,15,hour=TRUE)),tolerance=1e-12)
  expect_equal(suppressWarnings(calZenith(local,0,15,hour=FALSE)),
    suppressWarnings(calZenith(utc,0,15,hour=FALSE)),tolerance=1e-12)
})

test_that("legacy scalar component adapters follow common row validation", {
  expect_warning(x <- fTg(30,50,1010,-1,0.13,700,0.8,0.5),"invalid=1")
  expect_true(is.na(x))
  expect_warning(x <- fTnwb(30,20,101,1010,1,0.13,700,0.8,0.5),"invalid=1")
  expect_true(is.na(x))
  expect_no_warning(x <- fTg(NA_real_,50,1010,1,0.13,700,0.8,0.5))
  expect_true(is.na(x))
  expect_error(fTg(c(30,31),50,1010,1,0.13,700,0.8,0.5),"scalar")
})
