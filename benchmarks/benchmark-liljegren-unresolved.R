#!/usr/bin/env Rscript

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
root <- normalizePath(if (length(script_arg)) {
  file.path(dirname(sub("^--file=", "", script_arg[1])), "..")
} else {
  getwd()
})
source(file.path(root, "benchmarks", "liljegren-benchmark-utils.R"))
pkgload::load_all(root, quiet = TRUE)

rows <- liljegren_parse_positive_integers("LILJEGREN_ROWS", 100000L)
if (length(rows) != 1L) stop("LILJEGREN_ROWS must be one positive integer")
mode <- liljegren_coordinate_modes("LILJEGREN_UNRESOLVED_COORDINATE_MODES", "grouped")
if (length(mode) != 1L) stop("LILJEGREN_UNRESOLVED_COORDINATE_MODES must select one mode")
weather <- liljegren_workload(rows, mode = mode, path = liljegren_dataset_path(root))
result <- suppressWarnings(wbgt.Liljegren(
  weather$tas, weather$dewp, weather$wind, weather$radiation, weather$dates,
  lon = weather$lon, lat = weather$lat, hour = TRUE,
  engine = Sys.getenv("LILJEGREN_ENGINE", "batch"), diagnostics = TRUE
))
zenith <- liljegren_benchmark_zenith(weather$dates, weather$lon, weather$lat)

component_rows <- function(name) {
  d <- result$diagnostics[[name]]
  failed <- which(result$diagnostics$attempted & !d$converged)
  fallback_result <- if (is.null(d$fallback_converged)) rep(NA, length(failed)) else
    d$fallback_converged[failed]
  data.frame(
    row_index = failed, coordinate_mode = rep(mode, length(failed)), lon = weather$lon[failed], lat = weather$lat[failed],
    tas = weather$tas[failed], dewp = weather$dewp[failed], wind = weather$wind[failed],
    radiation = weather$radiation[failed], date = as.character(weather$dates)[failed],
    zenith_angle = zenith[failed], solar_geometry_mismatch = result$diagnostics$solar_geometry_mismatch[failed],
    failed_component = rep(name, length(failed)), failure_reason = d$failure_reason[failed],
    initial_lower = d$initial_lower[failed], initial_upper = d$initial_upper[failed],
    final_lower = d$final_lower[failed], final_upper = d$final_upper[failed],
    lower_residual = d$lower_residual[failed], upper_residual = d$upper_residual[failed],
    candidate_root = d$candidate_root[failed], candidate_final_residual = d$final_residual[failed],
    batch_fallback_attempted = d$used_fallback[failed],
    scalar_fallback_result = fallback_result, row.names = NULL
  )
}

solar_geometry_rows <- function() {
  mismatch <- which(result$diagnostics$solar_geometry_mismatch)
  data.frame(
    row_index = mismatch, coordinate_mode = rep(mode, length(mismatch)), lon = weather$lon[mismatch], lat = weather$lat[mismatch],
    tas = weather$tas[mismatch], dewp = weather$dewp[mismatch], wind = weather$wind[mismatch],
    radiation = weather$radiation[mismatch], date = as.character(weather$dates)[mismatch],
    zenith_angle = zenith[mismatch], solar_geometry_mismatch = rep(TRUE, length(mismatch)),
    failed_component = rep("solar_geometry", length(mismatch)),
    failure_reason = rep("radiation_gt_15_zenith_gt_1.54", length(mismatch)),
    initial_lower = rep(NA_real_, length(mismatch)), initial_upper = rep(NA_real_, length(mismatch)),
    final_lower = rep(NA_real_, length(mismatch)), final_upper = rep(NA_real_, length(mismatch)),
    lower_residual = rep(NA_real_, length(mismatch)), upper_residual = rep(NA_real_, length(mismatch)),
    candidate_root = rep(NA_real_, length(mismatch)),
    candidate_final_residual = rep(NA_real_, length(mismatch)),
    batch_fallback_attempted = rep(NA, length(mismatch)),
    scalar_fallback_result = rep(NA, length(mismatch)), row.names = NULL
  )
}

diagnostics <- list(Tg = component_rows("Tg"), Tnwb = component_rows("Tnwb"),
  solar_geometry = solar_geometry_rows())
print(data.frame(liljegren_workload_metadata(weather),
  solar_geometry_mismatches = nrow(diagnostics$solar_geometry)))
print(table(diagnostics$Tg$failure_reason))
print(table(diagnostics$Tnwb$failure_reason))
output <- Sys.getenv("BENCHMARK_OUTPUT", unset = "")
if (nzchar(output)) utils::write.csv(do.call(rbind, diagnostics), output, row.names = FALSE)
