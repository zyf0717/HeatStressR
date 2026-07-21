#' Calculate the convective heat transfer coefficient for a long cylinder in cross flow.
#' 
#' Calculate the convective heat transfer coefficient for a long cylinder in cross flow.
#' 
#' @param Tk value of air temperature in Kelvin.
#' @param Pair value of air pressure in hPa.
#' @param speed value of wind speed in m/s.
#' @param min.speed value of minimum wind speed in m/s.
#' @param diam.wick diameter of the cylinder in m.
#' 
#' @return Convective heat transfer coefficient for a long cylinder, W/(m2 K).
#' 
#' @author Ana Casanueva (05.01.2017).
#' @details Reference: Bedingfield and Drew, eqn 32.


h_cylinder_in_air_core <- function(Tk, Pair, speed, min.speed, diam.wick){
  
  # Constants
  r.air <- R_DRY_AIR
  cp <- CP_DRY_AIR
  Pr <- PRANDTL_AIR
  
  # Calculate the thermal conductivity of air, W/(m K)
  mu <- viscosity(Tk)
  therm.con <- (cp + 1.25 * r.air) * mu
  
  # Density of the air
  density <- Pair * 100 / (r.air * Tk)
  speed <- pmax(speed, min.speed)
  
  # Reynolds number
  Re <- speed * density * diam.wick / mu
  
  # Nusselt number
  Nu <- 0.281 * Re ^ 0.6 * Pr ^ 0.44
  
  # Convective heat transfer coefficient in W/(m2 K) for a long cylinder in cross flow
  Nu * therm.con / diam.wick
}

h_cylinder_in_air <- function(Tk, Pair, speed, min.speed, diam.wick){
  h_cylinder_in_air_core(Tk, Pair, speed, min.speed, diam.wick)
}
