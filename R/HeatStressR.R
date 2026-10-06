#' Meteorological heat-stress metrics
#'
#' Canonical single-index functions, registry-driven multi-index calculations,
#' aligned input validation and optional diagnostics. The package includes the
#' vectorized R Liljegren WBGT model and delegates Romps thermodynamic wet bulb
#' and the 2026 Lu Heat Index to the authors' heatindex package.
#'
#' @eval paste0("@details Available methods:\n", .method_catalog_rd())
#' @details Temperatures use Celsius, pressure hPa, humidity percent, wind m/s,
#'   and radiation W/m2. Consult [heat_methods()] for phase conventions, wind
#'   measurement height, applicability and scientific references. Missing inputs
#'   propagate silently; invalid rows become NA with summarized warnings.
#'   Scalar observations expand to the common input length.
#'
#'   [wbgt_liljegren()] evaluates instantaneous states, using batch roots,
#'   scalar fallback and optional PSOCK workers. Its independently maintained R
#'   model is not a bitwise port of the original Liljegren program. Validated
#'   component temperatures are retained when another component fails.
#'
#'   HeatStressR is a GPL-3 fork of HeatStress. Ana Casanueva authored the
#'   original package and R translation; Yifei Zheng maintains this fork.
#'   Historical contributions and attribution are retained. The fork is not
#'   affiliated with the original project or its authors.
#'
#'   Deprecated 2.x adapters preserve signatures and return shapes while
#'   applying documented scientific corrections. Removal is planned no earlier
#'   than v4.0.0. See [HeatStressR-deprecated] and the installed migration guide.
#'   Package attachment performs no network access. Use
#'   `citation("HeatStressR")` for the package citation. Please also cite the
#'   original methodological reference for each heat-stress method used; see the
#'   corresponding function documentation.
#' @seealso [heat_methods()], [heat_indices()], [wbgt_liljegren()]
#' @name HeatStressR
NULL
