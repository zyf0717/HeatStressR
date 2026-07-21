####################################################################
#
# Test-only scalar reference for calZenith().
#
# Preserves the pre-vectorization implementation as an oracle for
# element-wise equivalence tests; it is not part of the package API.
#
####################################################################

reference_calZenith_scalar <- local({
  # Keep these bindings and the function body aligned with the scalar source;
  # do not apply vectorization or numerical corrections in this reference.
  is.leapyear <- HeatStressR:::is.leapyear
  degToRad <- HeatStressR:::degToRad
  radToDeg <- HeatStressR:::radToDeg

  function(dates, lon, lat, hour = FALSE) {
    # Internal constants used for conversion
    EQTIME1 <- 229.18
    EQTIME2 <- 0.000075
    EQTIME3 <- 0.001868
    EQTIME4 <- 0.032077
    EQTIME5 <- 0.014615
    EQTIME6 <- 0.040849

    DECL1 <- 0.006918
    DECL2 <- 0.399912
    DECL3 <- 0.070257
    DECL4 <- 0.006758
    DECL5 <- 0.000907
    DECL6 <- 0.002697
    DECL7 <- 0.00148

    # Translate from date to utc.hour and year. If daily, set time to 12.
    if (hour) {
      d0 <- strftime(dates, format = "%Y-%m-%d %H:%M:%S", usetz = TRUE,
                     tz = "UTC")
      d1 <- strptime(d0, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")
      utc.minutes <- as.numeric(format(d1, "%H")) * 60 +
        as.numeric(format(d1, "%M")) + as.numeric(format(d1, "%S")) / 60
    } else {
      d1 <- strptime(dates, format = "%Y-%m-%d")
      utc.minutes <- 12 * 60
    }
    year <- as.numeric(format(d1, "%Y"))

    # Translate from date to doy
    doy <- as.numeric(strftime(d1, format = "%j"))

    # Number of days per year (check if it is a leap year)
    if (is.leapyear(year)) dpy <- 366 else dpy <- 365

    # Evaluate the input latitude in radians
    RadLat <- degToRad(lat)

    # Evaluate the fractional year in radians
    utc.hour <- utc.minutes / 60
    Gamma <- 2 * pi * ((doy - 1) + ((utc.hour - 12) / 24)) / dpy

    # Evaluate the Equation of time in minutes
    EquTime <- EQTIME1 * (EQTIME2 + EQTIME3 * cos(Gamma) -
      EQTIME4 * sin(Gamma) - EQTIME5 * cos(2 * Gamma) -
      EQTIME6 * sin(2 * Gamma))

    # Evaluate the solar declination angle in radians
    Decli <- DECL1 - DECL2 * cos(Gamma) + DECL3 * sin(Gamma) -
      DECL4 * cos(2 * Gamma) + DECL5 * sin(2 * Gamma) -
      DECL6 * cos(3 * Gamma) + DECL7 * sin(3 * Gamma)

    # UTC timestamps require longitude and equation-of-time corrections.
    TrueSolarTime <- (utc.minutes + EquTime + 4 * lon) %% 1440

    # Solar hour angle in degrees and in radians
    HaDeg <- ((TrueSolarTime / 4) - 180)
    HaRad <- degToRad(HaDeg)

    # Calculate the cosine of zenith angle
    CosZen <- sin(RadLat) * sin(Decli) +
      cos(RadLat) * cos(Decli) * cos(HaRad)
    if (CosZen > 1.0) CosZen <- 1.0
    if (CosZen < -1.0) CosZen <- -1.0

    # Calculate the zenith angle
    SZARad <- acos(CosZen)
    SZA <- radToDeg(SZARad)

    SZA
  }
})
