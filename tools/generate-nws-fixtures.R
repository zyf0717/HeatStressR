#!/usr/bin/env Rscript
# Independent NWS Heat Index procedure; Fahrenheit until final conversion.
# Source: https://www.wpc.ncep.noaa.gov/html/heatindex_equation.shtml
# Run from the repository root: Rscript tools/generate-nws-fixtures.R
# Regeneration is explicit; this script does not import HeatStressR.

nws <- function(t, rh) {
  simple <- (0.5 * (t + 61 + (t - 68) * 1.2 + rh * 0.094) + t) / 2
  if (simple < 80) return(simple)

  value <- -42.379 + 2.04901523 * t + 10.14333127 * rh -
    0.22475541 * t * rh - 0.00683783 * t * t -
    0.05481717 * rh * rh + 0.00122874 * t * t * rh +
    0.00085282 * t * rh * rh - 0.00000199 * t * t * rh * rh
  if (rh < 13 && t >= 80 && t <= 112) {
    value <- value - (13 - rh) / 4 * sqrt((17 - abs(t - 95)) / 17)
  }
  if (rh > 85 && t >= 80 && t <= 87) {
    value <- value + (rh - 85) / 10 * (87 - t) / 5
  }
  value
}

x <- expand.grid(
  hurs = c(0, 5, 10, 13, 13.001, 50, 85, 85.001, 99, 100),
  temperature_f = c(32, 68, 77, 79.999, 80, 80.001, 85, 87, 87.001,
    90, 95, 112, 112.001)
)[c("temperature_f", "hurs")]
x$heat_index_c <- (mapply(nws, x$temperature_f, x$hurs) - 32) / 1.8
write.csv(x, "tests/testthat/fixtures/nws-heat-index.csv", row.names = FALSE)
