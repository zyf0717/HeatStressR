test_that("canonical calculations do not depend on deprecated endpoints", {
  retired <- c(names(HeatStressR:::.legacy_endpoints), "resolve_solar_time",
    "calculate_liljegren_zenith", "tashurs2dewp", ".legacy_times", ".legacy_swap")
  mocks <- stats::setNames(rep(list(function(...) stop("deprecated dependency")),length(retired)),retired)
  do.call(testthat::local_mocked_bindings, c(mocks,list(.package="HeatStressR",.env=environment())))
  time <- as.POSIXct("2024-06-01 12:00:00",tz="UTC")
  expect_no_error(heat_indices(30,70,dewp=20,wind_10m=2,wind_2m=1,
    radiation=700,time=time,lon=0,lat=15))
  expect_no_error(solar_zenith(time,0,15))
  expect_no_error(vapour_pressure(30,70))
  expect_no_error(relative_humidity(30,20))
})
