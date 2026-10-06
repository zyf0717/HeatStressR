# The sole source of method names, requirements, kernels, units and provenance.
.method <- function(longname, inputs, kernel, reference, aliases = character(),
                    domain = "No quantitative applicability boundary specified",
                    domain_check = NULL, wind_height = NA_real_,
                    humidity = "Caller-provided RH (%); no internal saturation-law conversion") {
  list(longname = longname, inputs = inputs, kernel = kernel, reference = reference,
    aliases = aliases, units = "degC", domain = domain, domain_check = domain_check,
    wind_height = wind_height, humidity = humidity)
}

.method_registry <- list(
  wet_bulb_stull = .method("Stull wet-bulb approximation", c("tas", "hurs"),
    function(x, cache, options) list(values = .wbt_stull(x$tas, x$hurs)),
    "10.1175/JAMC-D-11-0143.1", aliases = c("wbt", "wbt.Stull"),
    domain = "-20 <= tas <= 50 C; 5 <= hurs <= 99%; sea-level pressure; cold/dry corner excluded",
    domain_check = function(x) {
      outside <- x$tas < -20 | x$tas > 50 | x$hurs < 5 | x$hurs > 99
      ifelse(outside, "outside", ifelse(x$tas < 0, "unknown", "within"))
    }),
  wet_bulb_romps = .method("Romps thermodynamic liquid-water wet bulb",
    c("tas", "hurs", "pressure"),
    function(x, cache, options) .modern_result("wetbulb", x),
    "10.1175/JAMC-D-25-0130.1", humidity = "Water above 273.16 K; ice at or below 273.16 K (heatindex 0.0.2)"),
  wbgt_simplified_abm = .method("ABM simplified WBGT", c("tas", "hurs"),
    function(x, cache, options) list(values = 0.567 * x$tas + 0.393 * .shared_vapour(x, cache) + 3.94),
    "10.2486/indhealth.MS1352, equation 12",
    humidity = "Dosseger vapour pressure: water at tas >= 0 C, ice below 0 C"),
  wbgt_simplified_indoor = .method("Indoor simplified WBGT", c("tas", "hurs"),
    function(x, cache, options) list(values = 0.567 * x$tas + 0.216 * .shared_vapour(x, cache) + 3.38),
    "10.2486/indhealth.MS1352, equation 14", aliases = "swbgt",
    humidity = "Dosseger vapour pressure: water at tas >= 0 C, ice below 0 C"),
  apparent_temperature = .method("Apparent temperature", c("tas", "hurs", "wind_10m"),
    function(x, cache, options) list(values = x$tas + 0.33 * .shared_vapour(x, cache) - 0.7 * x$wind_10m - 4),
    "Steadman (1994); 10.5194/gmd-8-151-2015", aliases = "apparentTemp", wind_height = 10,
    humidity = "Dosseger vapour pressure: water at tas >= 0 C, ice below 0 C"),
  effective_temperature = .method("Effective temperature", c("tas", "hurs", "wind_10m"),
    function(x, cache, options) list(values = 37 - (37 - x$tas) / (0.68 - 0.0014 * x$hurs +
      1 / (1.76 + 1.4 * x$wind_10m ^ 0.75)) - 0.29 * x$tas * (1 - 0.01 * x$hurs)),
    "Coccolo et al. (2016), 10.1016/j.uclim.2016.08.004", aliases = "effectiveTemp", wind_height = 10),
  humidex = .method("Humidex (Celsius-equivalent scale)", c("tas", "hurs"),
    function(x, cache, options) list(values = x$tas + 5 / 9 * (.shared_vapour(x, cache) - 10)),
    "Masterton and Richardson (1979)",
    humidity = "Dosseger vapour pressure: water at tas >= 0 C, ice below 0 C"),
  discomfort_index = .method("Discomfort index", c("tas", "hurs"),
    function(x, cache, options) list(values = x$tas - 0.55 * (1 - 0.01 * x$hurs) * (x$tas - 14.5)),
    "Thom (1959)", aliases = "discomInd"),
  heat_index_rothfusz = .method("NWS Rothfusz Heat Index", c("tas", "hurs"),
    function(x, cache, options) list(values = .heat_index(x$tas, x$hurs)),
    "https://www.wpc.ncep.noaa.gov/html/heatindex_equation.shtml", aliases = "hi",
    domain = "NWS simple/regression procedure; extreme-condition validity is not numerically specified"),
  heat_index_lu = .method("Lu et al. (2026) simplified Heat Index", c("tas", "hurs"),
    function(x, cache, options) .modern_result("heatindex", x),
    "10.1175/JAMC-D-25-0067.1", humidity = "Water above 273.16 K; ice at or below 273.16 K (heatindex 0.0.2)"),
  wbgt_bernard = .method("Bernard indoor/shade WBGT", c("tas", "dewp"),
    function(x, cache, options) .bernard_result(x, options),
    "10.2486/indhealth.MS1352", aliases = c("wbgt.Bernard", "wbgt_shade"), humidity = "Dew point; Bernard saturation-pressure law"),
  wbgt_liljegren = .method("Liljegren outdoor WBGT",
    c("tas", "dewp", "wind_2m", "radiation", "time", "lon", "lat", "pressure"),
    function(x, cache, options) .liljegren_result(x, options),
    "10.1080/15459620802310770", aliases = c("wbgt.Liljegren", "wbgt_sun"),
    wind_height = 2, humidity = "Dosseger dewpoint-to-RH conversion; Buck water saturation in heat balances")
)

.shared_vapour <- function(x, cache) {
  if (is.null(cache)) return(.vapour_pressure_hpa(x$tas, x$hurs))
  # Group by validated humidity inputs: wind-related missing rows do not change e.
  if (!exists("vapour", cache, inherits = FALSE)) cache$vapour <- .vapour_pressure_hpa(x$tas, x$hurs)
  cache$vapour
}

#' Discover available heat-stress methods
#'
#' @return A data frame containing canonical method names, aliases, required
#'   inputs, units, applicability descriptions, humidity conventions, wind
#'   heights and scientific references. An unknown boundary does not establish
#'   validity. Humidex is reported on its Celsius-equivalent scale.
#' @export
#' @examples
#' heat_methods()
heat_methods <- function() {
  rows <- lapply(names(.method_registry), function(name) {
    m <- .method_registry[[name]]
    data.frame(method = name, longname = m$longname,
      aliases = paste(m$aliases, collapse = ", "),
      required_inputs = paste(m$inputs, collapse = ", "), units = m$units,
      domain = m$domain, humidity_reference = m$humidity,
      wind_height_m = m$wind_height, reference = m$reference,
      input_units = paste(paste(m$inputs, .input_units[m$inputs], sep = "="), collapse = ", "),
      stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

# Used by roxygen so the installed catalog and discovery table share metadata.
.method_catalog_rd <- function() {
  lines <- vapply(names(.method_registry), function(name) {
    m <- .method_registry[[name]]
    paste0("\\item{\\code{", name, "}}{", m$longname, "; inputs: ",
      paste(m$inputs, collapse = ", "), "; units: ", m$units, ".}")
  }, character(1))
  paste0("\\describe{", paste(lines, collapse = "\n"), "}")
}
