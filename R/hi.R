#' Calculation of the heat index.
#' 
#' Calculation of the heat index from temperature and relative humidity.
#' 
#' @param tas vector of air temperature in degC.
#' @param hurs vector of relative humidity in \%.
#' 
#' @return Heat index in degC.
#' @author A.Casanueva (22.03.2018). Modified in 12.08.2025.
#' @details Formula based on air temperature and relative humidity, following Rothfusz 1990 (National Weather Service Technical Attachment, SR 90-23). The NWS equations and adjustments are evaluated in degrees Fahrenheit internally and the final heat index is returned in degrees Celsius. This implementation includes some adjustments for high and low relative humidity values. Also, the original formula is not appropriate for low temperatures and heat index values. In those cases, a simpler formula is applied to calculate values consistent with Steadman's results. See: https://www.wpc.ncep.noaa.gov/html/heatindex_equation.shtml and https://github.com/ecmwf/thermofeel/blob/master/thermofeel/thermofeel.py#L782
#'  
#' @export
#' 
#' @examples \dontrun{ 
#' # load the meteorological variables for example data in Salamanca:
#' data("data_obs") 
#' heatindex <- hi(data_obs$tasmean, hurs=data_obs$hurs)
#' }
#' 



hi <- function(tas,hurs){
  .validate_tas_hurs(tas, hurs)
  .heat_index(tas, hurs)
}
