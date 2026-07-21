#' Calculate the convective heat tranfer coefficient for flow around a sphere.
#' 
#' Calculate the convective heat tranfer coefficient for flow around a sphere.
#' 
#' @param diam.globe diameter of the sphere in m.
#' @inheritParams h_cylinder_in_air
#' 
#' @return Convective heat tranfer coefficient for flow around a sphere, W/(m2 K).
#' 
#' @author Ana Casanueva (05.01.2017).
#' @details Reference: Bird, Stewart, and Lightfoot (BSL), page 409.


h_sphere_in_air_core <- function(Tk, Pair, speed, min.speed, diam.globe){
  
  
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
  Re <- speed * density * diam.globe / mu
  
  # Nusselt number
  Nu <- 2 + 0.6 * Re ^ 0.5 * Pr ^ 0.3333
  
  # Convective heat tranfer coefficient for flow around a sphere, W/(m2 K)
  Nu * therm.con / diam.globe
}

h_sphere_in_air <- function(Tk, Pair, speed, min.speed, diam.globe){
  h_sphere_in_air_core(Tk, Pair, speed, min.speed, diam.globe)
}
