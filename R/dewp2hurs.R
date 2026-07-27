#' Calculation of relative humidity from temperature and dewpoint temperature.
#'
#' @param tas vector of temperature in degC
#' @param dewp vector of dewpoint temperature in degC
#'
#' @return relative humidity in %
#' @author Ana Casanueva (11.08.2016)
#'
#' @details Formulation from Dosseger et al. 1992. Formula 99 in MCH document.
#' @export


##################################################
##################################################


dewp2hurs <- function(tas,dewp){

assertthat::assert_that(length(tas) == length(dewp),
                        msg="Input vectors do not have the same length")

# Constants (see Dosseger et al. 1992)
# IF T ≥ 0: a = 17.368 and b = 238.83
# IF T < 0: a = 17.856 and b = 245.52
T0 <- 0 # degC
a1 <- 17.368
b1 <- 238.83
a2 <- 17.856
b2 <- 245.52
hurs <- rep(NA_real_, length(tas))

iceMask <- !is.na(tas) & tas < T0
waterMask <- !is.na(tas) & tas >= T0

hurs[waterMask] <- 100*exp(((a1*dewp[waterMask])/(b1+dewp[waterMask]))-((a1*tas[waterMask])/(b1+tas[waterMask])))
hurs[iceMask] <- 100*exp(((a2*dewp[iceMask])/(b2+dewp[iceMask]))-((a2*tas[iceMask])/(b2+tas[iceMask])))


hurs[hurs > 100] <- 100 
hurs[hurs < 0] <- 0 

return(hurs) 
}
