#' Calculation of the effective temperature.
#' 
#' Calculation of the effective temperature from temperature, relative humidity and wind.
#' 
#' @param tas vector of air temperature in degC.
#' @param hurs vector of relative humidity in \%.
#' @param wind vector of wind at 10m in m/s.
#' 
#' @return Effective temperature in degC.
#' @author A.Casanueva (22.03.2018).
#' @details Formula based on air temperature, relative humidity and wind, as it is calculated in Coccolo et al. 2016 and references therein.
#'  
#' @export
#' 
#' @examples
#' # load the meteorological variables for example data in Salamanca:
#' data("data_obs") 
#' et <- effectiveTemp(data_obs$tasmean, hurs=data_obs$hurs, wind=data_obs$wind)
#' 



effectiveTemp <- function(tas,hurs, wind){

  .validate_tas_hurs_wind(tas, hurs, wind)
  
  # calculation of the effective temperature
  result <- 37 - (37-tas)/(0.68 - 0.0014*hurs + 1/(1.76+ 1.4*(wind^0.75))) - 0.29 * tas * (1 - 0.01*hurs)
  
  return(result)
}
