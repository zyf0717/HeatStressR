#' Calculation of wet bulb temperature, following Stull's method.
#' 
#' Calculation of wet bulb temperature from temperature and relative humidity.
#' 
#' @param tas vector of air temperature in degC.
#' @param hurs vector of relative humidity in \%.
#' 
#' @return Wet bulb temperature in degC.
#' @author A.Casanueva (15.08.2016).
#' @details Formulation from Stull 2011, Journal of Applied Meteorology and Climatology.
#' 
#' @export
#' 
#' @examples \dontrun{ 
#' # load the meteorological variables for example data in Salamanca:
#' data("data_obs") 
#' wbt <- wbt.Stull(data_obs$tasmean, hurs=data_obs$hurs)
#' }
#' 

wbt.Stull <- function(tas,hurs){

  .validate_tas_hurs(tas, hurs)
  .wbt_stull(tas, hurs)

}
