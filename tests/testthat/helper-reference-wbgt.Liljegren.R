####################################################################
#
# Test-only scalar-zenith reference for wbgt.Liljegren().
#
# Preserves the existing per-row zenith path as an end-to-end oracle
# while the production implementation is optimized.
#
####################################################################

reference_wbgt.Liljegren_scalar_zenith <- local({
  # Only the zenith path is intentionally frozen here. The solver calls stay
  # shared with production because solver changes are outside this work.
  dewp2hurs <- HeatStress:::dewp2hurs
  degToRad <- HeatStress:::degToRad
  fTg <- HeatStress:::fTg
  fTnwb <- HeatStress:::fTnwb

  function(tas, dewp, wind, radiation, dates, lon, lat,
           tolerance = 1e-4, noNAs = TRUE, swap = FALSE, hour = FALSE) {
    propDirect <- 0.8
    Pair <- 1010
    MinWindSpeed <- 0.13

    assertthat::assert_that(is.logical(hour), msg = "'hour' should be logical")
    assertthat::assert_that(is.logical(noNAs), msg = "'noNAs' should be logical")
    assertthat::assert_that(is.logical(swap), msg = "'swap' should be logical")
    assertthat::assert_that(
      length(tas) == length(dewp) & length(dewp) == length(wind) &
        length(wind) == length(radiation),
      msg = "Input vectors do not have the same length"
    )
    assertthat::assert_that(is.numeric(Pair), msg = "'Pair' is not an integer")
    assertthat::assert_that(
      is.numeric(MinWindSpeed),
      msg = "'min.speed' is not an integer"
    )
    assertthat::assert_that(propDirect < 1, msg = "'propDirect' should be [0,1]")
    assertthat::assert_that(is.numeric(lon), msg = "'lon' is not an integer")
    assertthat::assert_that(is.numeric(lat), msg = "'lat' is not an integer")
    assertthat::assert_that(lon <= 180 & lon >= -180, msg = "Invalid lon")
    assertthat::assert_that(lat <= 90 & lat >= -90, msg = "Invalid lat")

    ndates <- length(tas)
    Tnwb <- rep(NA, ndates)
    Tg <- rep(NA, ndates)

    radiation[radiation < 0] <- 0
    wind[wind < 0] <- 0

    xmask <- !is.na(tas + dewp + wind + radiation)

    if (noNAs & swap) {
      tastmp <- pmax(tas, dewp)
      dewp <- pmin(tas, dewp)
      tas <- tastmp
    } else if (noNAs & !swap) {
      noway <- (dewp - tas) > tolerance
      dewp[which(noway)] <- tas[which(noway)]
    } else if (!noNAs) {
      xmask <- xmask & tas >= dewp
    }

    relh <- dewp2hurs(tas, dewp)

    for (i in which(xmask)) {
      zenithDeg <- reference_calZenith_scalar(dates[i], lon, lat, hour)
      ZenithAngle <- degToRad(zenithDeg)
      radiation.i <- radiation[i]
      if (!is.na(ZenithAngle) && cos(ZenithAngle) <= 0) radiation.i <- 0

      Tg[i] <- suppressWarnings(fTg(
        tas[i], relh[i], Pair, wind[i], MinWindSpeed, radiation.i,
        propDirect, ZenithAngle, tolerance = tolerance
      ))
      Tnwb[i] <- fTnwb(
        tas[i], dewp[i], relh[i], Pair, wind[i], MinWindSpeed, radiation.i,
        propDirect, ZenithAngle, tolerance = tolerance
      )
    }

    failed <- is.na(Tg) | is.na(Tnwb)
    Tg[failed] <- NA_real_
    Tnwb[failed] <- NA_real_
    list(
      data = 0.7 * Tnwb + 0.2 * Tg + 0.1 * tas,
      Tnwb = Tnwb,
      Tg = Tg
    )
  }
})
