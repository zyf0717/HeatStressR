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
mode <- liljegren_coordinate_modes("LILJEGREN_TOLERANCE_COORDINATE_MODES", "grouped")
if (length(mode) != 1L) stop("LILJEGREN_TOLERANCE_COORDINATE_MODES must select one mode")
weather <- liljegren_workload(rows, mode = mode, path = liljegren_dataset_path(root))

run <- function(residual_tolerance, engine = "batch") {
  measurement <- liljegren_measure(function() suppressWarnings(wbgt.Liljegren(
    weather$tas, weather$dewp, weather$wind, weather$radiation, weather$dates,
    lon = weather$lon, lat = weather$lat, hour = TRUE, engine = engine,
    diagnostics = TRUE, root_tolerance = 1e-6,
    residual_tolerance = residual_tolerance
  )), 1L)
  list(value = measurement$value, runtime = measurement$seconds)
}

limits <- c(1e-4, 3e-4, 1e-3, 3e-3, 1e-2)
baseline <- run(limits[1])
scalar <- run(limits[1], "scalar")
summarize <- function(limit) {
  current <- if (limit == limits[1]) baseline else run(limit)
  d <- current$value$diagnostics
  residuals <- abs(c(d$Tg$final_residual[d$Tg$converged],
    d$Tnwb$final_residual[d$Tnwb$converged]))
  failures <- c(d$Tg$failure_reason[!d$Tg$converged],
    d$Tnwb$failure_reason[!d$Tnwb$converged])
  delta <- function(component) {
    same <- !is.na(current$value[[component]]) & !is.na(baseline$value[[component]])
    if (any(same)) max(abs(current$value[[component]][same] - baseline$value[[component]][same])) else NA_real_
  }
  data.frame(
    residual_tolerance = limit, liljegren_workload_metadata(weather),
    accepted_rows = sum(d$complete_wbgt), rejected_rows = sum(!d$complete_wbgt),
    Tg_failures = sum(!d$Tg$converged), Tnwb_failures = sum(!d$Tnwb$converged),
    both_component_failures = sum(!d$Tg$converged & !d$Tnwb$converged),
    unbracketed_failures = sum(failures == "unbracketed"),
    non_finite_failures = sum(failures == "non_finite"),
    residual_validation_failures = sum(failures == "residual_validation"),
    maximum_accepted_residual = if (length(residuals)) max(residuals) else NA_real_,
    median_accepted_residual = if (length(residuals)) median(residuals) else NA_real_,
    maximum_Tg_difference_from_baseline = delta("Tg"),
    maximum_Tnwb_difference_from_baseline = delta("Tnwb"),
    maximum_WBGT_difference_from_baseline = delta("data"),
    runtime_seconds = current$runtime,
    fallback_count = sum(d$Tg$used_fallback, na.rm = TRUE) + sum(d$Tnwb$used_fallback, na.rm = TRUE),
    scalar_batch_decisions_match = identical(d$complete_wbgt, scalar$value$diagnostics$complete_wbgt),
    row.names = NULL
  )
}

result <- do.call(rbind, lapply(limits, summarize))
print(result, row.names = FALSE)
output <- Sys.getenv("BENCHMARK_OUTPUT", unset = "")
if (nzchar(output)) utils::write.csv(result, output, row.names = FALSE)
