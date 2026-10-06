# Run in the reference library; fixture regeneration is an explicit maintainer action.
stopifnot(as.character(utils::packageVersion("heatindex")) == "0.0.2")
x <- expand.grid(tas = c(-10, 0, 0.01, 20, 30, 40, 50),
  hurs = c(0, 5, 50, 99, 100), pressure = c(700, 1010))
x$wet_bulb_romps <- heatindex::wetbulb(x$pressure * 100, x$tas + 273.15,
  x$hurs / 100, psychrometric = FALSE, icebulb = FALSE, verbose = FALSE) - 273.15
x$heat_index_lu <- heatindex::heatindex(x$tas + 273.15, x$hurs / 100) - 273.15
write.csv(x, "tests/testthat/fixtures/heatindex-0.0.2.csv", row.names = FALSE)
