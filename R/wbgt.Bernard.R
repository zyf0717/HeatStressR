bernard_psychrometric_residual <- function(Tpwb, tas, ed) {
  c1 <- 6.106
  c2 <- 17.27
  c3 <- 237.3
  c4 <- 1556
  c5 <- 1.484
  c6 <- 1010

  saturation_pressure <- c1 * exp((c2 * Tpwb) / (c3 + Tpwb))
  c4 * ed - c5 * ed * Tpwb - c4 * saturation_pressure +
    c5 * saturation_pressure * Tpwb + c6 * (tas - Tpwb)
}

bernard_bisection <- function(tas, dewp, ed, tolerance,
                              max_iterations = 64L) {
  lower <- dewp
  upper <- tas
  lower_residual <- bernard_psychrometric_residual(lower, tas, ed)
  upper_residual <- bernard_psychrometric_residual(upper, tas, ed)
  bracketed <- is.finite(lower_residual) & is.finite(upper_residual) &
    (lower_residual == 0 | upper_residual == 0 |
      sign(lower_residual) != sign(upper_residual))
  root <- rep(NA_real_, length(tas))

  lower_root <- bracketed & lower_residual == 0
  upper_root <- bracketed & !lower_root & upper_residual == 0
  root[lower_root] <- lower[lower_root]
  root[upper_root] <- upper[upper_root]
  active <- bracketed & is.na(root) & (upper - lower > tolerance)

  for (iteration in seq_len(max_iterations)) {
    idx <- which(active)
    if (!length(idx)) break

    midpoint <- lower[idx] + (upper[idx] - lower[idx]) / 2
    midpoint_residual <- bernard_psychrometric_residual(
      midpoint, tas[idx], ed[idx]
    )
    finite <- is.finite(midpoint_residual)
    if (any(finite)) {
      update_idx <- idx[finite]
      same_as_lower <- sign(midpoint_residual[finite]) ==
        sign(lower_residual[update_idx])
      lower_idx <- update_idx[same_as_lower]
      upper_idx <- update_idx[!same_as_lower]
      lower[lower_idx] <- midpoint[finite][same_as_lower]
      lower_residual[lower_idx] <- midpoint_residual[finite][same_as_lower]
      upper[upper_idx] <- midpoint[finite][!same_as_lower]
      upper_residual[upper_idx] <- midpoint_residual[finite][!same_as_lower]

      exact_idx <- update_idx[midpoint_residual[finite] == 0]
      root[exact_idx] <- midpoint[finite][midpoint_residual[finite] == 0]
    }
    active[idx[!finite]] <- FALSE
    active[idx[finite]] <- is.na(root[idx[finite]]) &
      (upper[idx[finite]] - lower[idx[finite]] > tolerance)
  }

  converged <- bracketed & (is.finite(root) | (upper - lower <= tolerance))
  root[converged & is.na(root)] <- (lower[converged & is.na(root)] +
    upper[converged & is.na(root)]) / 2
  list(root = root, converged = converged)
}

#' Calculation of wet bulb globe temperature, following Bernard's method.
#' 
#' Calculation of wet bulb globe temperature from air temperature and dew point temperature. This corresponds to the implementation for indoors or shadow conditions.
#' 
#' @param tas vector of air temperature in degC.
#' @param dewp vector of dew point temperature in degC.
#' @param tolerance (optional): maximum final bracket width for the psychrometric
#'   wet-bulb solution. Default: 1e-4.
#' @param noNAs logical, should NAs be introduced when dewp>tas? If TRUE specify how to deal in those cases (swap argument)
#' @param swap logical, should \code{tas >= dewp} be enforced by swapping? Otherwise, dewp is set to tas. This argument is needed when noNAs=T.
#' 
#' @return A list of:
#' @return $data: wet bulb globe temperature in degC.
#' @return $Tpwb: phychrometric wet bulb temperature (Tpwb) in degC.
#' @author A.Casanueva, P. Noti, J. Bhend (21.02.2017).
#' @details Based on Lemke and Kjellstrom 2012, using the formulation from Bernard et al. 1999. The psychrometric wet-bulb temperature is solved with vectorized bisection on the physical interval from dew point to air temperature.
#' @export
#' 
#' @examples
#' # load the meteorological variables for example data in Salamanca:
#' data("data_obs") 
#' wbgt.indoors <- wbgt.Bernard(tas=data_obs$tasmean, dewp=data_obs$dewp)
#' 
wbgt.Bernard <- function(tas, dewp, tolerance= 1e-4, noNAs=TRUE, swap=FALSE){

  # assertion statements
  assertthat::assert_that(length(tas)==length(dewp), 
                          msg="Input vectors do not have the same length")
  
  ##################################################
  ##################################################
  # Constants (see Lemke and Kjellstrom 2012)
  c1 <- 6.106
  c2 <- 17.27
  c3 <- 237.3
  
  # pre-allocate output
  ndates <- length(tas)
  Tpwb <- rep(NA_real_, ndates)
  
  
  # **************************************************************************************
  # *** calculate the phychrometric wet bulb temperature (Tpwb) in degC, by iteration ***
  # **************************************************************************************
  # Filter the case when tas=dewp (RH=100)
  trivial <- abs(tas - dewp) < tolerance
  trivial_idx <- which(trivial)
  Tpwb[trivial_idx] <- tas[trivial_idx]
  
  # Filter data to calculate the WBGT with optimization function
  xmask <- !is.na(tas + dewp) & !trivial 
  
  # Swap temperature and dewpoint if necessary
  if (noNAs & swap){
    tastmp <- pmax(tas, dewp)
    dewp <- pmin(tas, dewp)
    tas <- tastmp
  } else if(noNAs & !swap){
    noway <- (dewp - tas) > tolerance
    xmask <- xmask & !noway
    noway_idx <- which(noway)
    Tpwb[noway_idx] <- tas[noway_idx]
  } else if(!noNAs){
    xmask <- xmask & tas >= dewp
  }
  
  # ********************************************************************
  # *** calculate the vapour pressure from the dew point (ed) in hPa ***
  # ********************************************************************
  ed <- c1 * exp((c2*dewp)/(c3+dewp))
  
  valid_idx <- which(xmask)
  if (length(valid_idx)) {
    solved <- bernard_bisection(
      tas[valid_idx], dewp[valid_idx], ed[valid_idx], tolerance
    )
    Tpwb[valid_idx[solved$converged]] <- solved$root[solved$converged]
  }
  
  # *******************************
  # *** Calculation of the WBGT ***
  # *******************************
  wbgt <- list(Tpwb = Tpwb, 
               data = 0.67*Tpwb + 0.33 * tas)
  
  return(wbgt)
}
