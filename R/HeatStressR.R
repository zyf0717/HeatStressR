#' HeatStressR
#' 
#' Calculate heat stress indices
#' 
#' The package \code{HeatStressR} calculates heat-stress indices from
#' meteorological observations and exposes both index-level functions and
#' lower-level physical components.
#'
#' @details
#'
#' The following calculation methods are implemented:
#'  \itemize{
#'  
#'  \item \code{wbt.Stull}: Calculation of the Wet Bulb Temperature (Stull 2011).
#'  \item \code{wbgt.Bernard}: Calculation of the Wet Bulb Globe Temperature in the shade (Bernard et al. 1999) 
#'  \item \code{wbgt.Liljegren}: Calculation of the Wet Bulb Globe Temperature in the sun (Liljegren et al. 2008) 
#'  \item \code{swbgt}: Calculation of the simplified wet bulb globe temperature (Buzan et al. 2015 and references therein).
#'  \item \code{apparentTemp}: Calculation of the apparent temperature (Buzan et al. 2015 and references therein).
#'  \item \code{effectiveTemp}: Calculation of the effective temperature (Coccolo et al. 2016 and references therein).
#'  \item \code{humidex}: Calculation of the humidex (Buzan et al. 2015 and references therein).
#'  \item \code{discomInd}: Calculation of the discomfort index (Coccolo et al. 2016 and references therein).
#'  \item \code{hi}: Calculation of the heat index (NOAA, Rothfusz 1990).

#' }
#'
#' \code{wbgt.Liljegren()} implements the outdoor Liljegren wet-bulb globe
#' temperature model. Its corrected scalar engine is the default; the batch
#' engine is opt-in and can use explicitly requested PSOCK workers. Pressure
#' and documented physical constants are configurable. Set
#' \code{diagnostics = TRUE} to obtain row-aligned input and solver metadata.
#' The implementations are not necessarily interchangeable with other WBGT
#' programs.
#'
#' Invalid inputs and numerical solver failures are distinct. Complete WBGT is
#' \code{NA} unless both globe and natural-wet-bulb temperatures validate, while
#' an independently valid component can be retained. Diagnostic vectors remain
#' aligned with the supplied meteorological rows.
#'
#' HeatStressR is an independently maintained fork of the HeatStress package.
#' Ana Casanueva made the original R translation; this fork adds numerical
#' robustness, solar-geometry corrections, row-level diagnostics, and optional
#' batch execution. It is maintained by Yifei Zheng and is not affiliated with
#' the original project or its authors. The source repository is
#' \url{https://github.com/zyf0717/HeatStressR}.
#'
#' CRAN checks package portability and software quality; users remain
#' responsible for matching the methodological assumptions of a chosen index to
#' their application. To cite the package and the Liljegren model, use
#' \code{citation("HeatStressR")}.
#'
#' Check the details of the indices and input variables with
#' \code{indexShow()}.
#'
#' @name HeatStressR
#'  
NULL 
#"_PACKAGE"
