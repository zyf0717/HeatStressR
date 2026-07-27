#' Calculation of vapour pressure.
#' 
#' Calculation of vapour pressure from temperature and relative humidity
#' 
#' @param tas vector of air temperature in degC.
#' @param hurs vector of relative humidity in \%.
#' 
#' @return Vapour pressure in hPa.
#' @author A.Casanueva (11.08.2016).
#' @details Formulation from Dosseger et al. 1992. Formula 16 in MCH document.
#'  
#' @export
#' 
#' @examples \dontrun{ 
#' # load the meteorological variables for example data in Salamanca:
#' data("data_obs") 
#' vp <- tashurs2vap.pres(data_obs$tasmean, hurs=data_obs$hurs)
#' }
#' 


tashurs2vap.pres <- function(tas,hurs){
  assertthat::assert_that(length(hurs) == length(tas),
    msg="Input vectors do not have the same length")
  .vapour_pressure_hpa(tas, pmin(hurs, 100))
}
