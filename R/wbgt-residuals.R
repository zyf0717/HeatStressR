# Globe heat balance in energy form. A zero is equivalent to
# A(Tg)^(1/4) - Tg = 0 wherever the latter is real, without requiring a
# fractional power while locating the root.
fTg_energy_residual <- function(Tglobe, Tair, Pair, wind, longwave, solar,
                                diam.globe = 0.05, emis.globe = 0.95) {
  if (!length(Tglobe)) return(numeric())
  h <- h_sphere_in_air_core(0.5 * (Tglobe + Tair), Pair, wind, wind,
                            diam.globe)
  longwave - h / (emis.globe * STEFAN_BOLTZMANN) * (Tglobe - Tair) +
    solar - Tglobe ^ 4
}

# Retained for residual acceptance and reporting in K. Root location uses the
# energy residual above; this scale-preserving form keeps residual_tolerance's
# documented units and public behavior intact.
fTg_residual <- function(Tglobe, Tair, Pair, wind, longwave, solar,
                         diam.globe = 0.05, emis.globe = 0.95) {
  if (!length(Tglobe)) return(numeric())
  energy <- fTg_energy_residual(Tglobe, Tair, Pair, wind, longwave, solar,
    diam.globe, emis.globe)
  reference <- energy + Tglobe ^ 4
  reference ^ 0.25 - Tglobe
}

fTnwb_residual <- function(Twb, Tair, Pair, wind, eair, density,
                           viscosity.air, diffusivity.coefficient, longwave,
                           solar, irad = 1, diam.wick = 0.007,
                           emis.wick = 0.95) {
  if (!length(Twb)) return(numeric())
  tref <- 0.5 * (Twb + Tair)
  Sc <- viscosity.air / (density *
    diffusivity_from_coefficient(tref, diffusivity.coefficient))
  h <- h_cylinder_in_air_core(Twb, Pair, wind, wind, diam.wick)
  ewick <- esat(Twb)
  Fatm <- STEFAN_BOLTZMANN * emis.wick * (longwave - Twb ^ 4) + solar
  Tair - h_evap(Twb) / WBGT_EVAPORATION_RATIO *
    (ewick - eair) / (Pair - ewick) * (PRANDTL_AIR / Sc) ^ 0.56 +
    Fatm / h * irad - Twb
}
