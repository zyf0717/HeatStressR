#' Compute the diffusivity of water vapor in air.
#' 
#' Compute the diffusivity of water vapor in air, m2/s
#' 
#' @inheritParams h_cylinder_in_air
#'  
#' @return  diffusivity of water vapor in air, m2/s
#' 
#' @author Ana Casanueva (05.01.2017).
#' @details Reference: BSL, page 505.
#' 

diffusivity_coefficient <- function(Pair) {

  pcrit13 <- (36.4 * 218) ^ (1 / 3)
  Mmix <- (1 / 28.97 + 1 / 18.015) ^ 0.5
  base <- 0.000364 * pcrit13 * (132 * 647.3) ^ (5 / 12) * Mmix /
    (Pair / 1013.25) * 0.0001
  base / ((132 * 647.3) ^ 0.5) ^ 2.334
}

diffusivity_from_coefficient <- function(Tk, coefficient) {
  coefficient * Tk ^ 2.334
}

diffusivity <- function(Tk, Pair){
  diffusivity_from_coefficient(Tk, diffusivity_coefficient(Pair))
}
