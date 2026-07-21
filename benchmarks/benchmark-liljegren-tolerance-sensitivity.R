#!/usr/bin/env Rscript

# Evaluate accepted roots and output stability across supported residual limits.
# Set BENCHMARK_OUTPUT to persist the summary CSV; default workload is 100,000 rows.

benchmark_root <- function() {
  arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  normalizePath(if (length(arg)) file.path(dirname(sub("^--file=", "", arg[1])), "..") else getwd())
}

make_weather <- function(n = 100000L, lon = -5.66, lat = 40.96) {
  index <- seq_len(n)
  phase <- 2 * pi * ((index - 1) %% 24) / 24
  dates <- as.POSIXct("2020-01-01 00:00:00", tz = "UTC") + (index - 1) * 3600
  zenith <- HeatStressR:::degToRad(calZenith(dates, lon, lat, hour = TRUE))
  list(tas = 22 + 8 * sin(phase - pi / 2),
    dewp = 22 + 8 * sin(phase - pi / 2) - rep(c(0, 2, 4, 6), length.out = n),
    wind = rep(c(0, 0.05, 0.2, 0.8, 1.5, 2.5), length.out = n),
    radiation = 850 * pmax(cos(zenith), 0), dates = dates)
}

root <- benchmark_root()
pkgload::load_all(root, quiet = TRUE)
weather <- make_weather(as.integer(Sys.getenv("LILJEGREN_ROWS", "100000")))
run <- function(residual_tolerance, engine = "batch") {
  started <- proc.time()[["elapsed"]]
  value <- suppressWarnings(wbgt.Liljegren(weather$tas, weather$dewp, weather$wind,
    weather$radiation, weather$dates, lon = -5.66, lat = 40.96, hour = TRUE,
    engine = engine, diagnostics = TRUE, root_tolerance = 1e-6,
    residual_tolerance = residual_tolerance))
  list(value = value, runtime = proc.time()[["elapsed"]] - started)
}

limits <- c(1e-4, 3e-4, 1e-3, 3e-3, 1e-2)
baseline <- run(limits[1])
scalar <- run(limits[1], "scalar")
summarize <- function(limit) {
  current <- if (limit == limits[1]) baseline else run(limit)
  d <- current$value$diagnostics
  accepted <- d$complete_wbgt
  residuals <- abs(c(d$Tg$final_residual[d$Tg$converged],
    d$Tnwb$final_residual[d$Tnwb$converged]))
  failures <- c(d$Tg$failure_reason[!d$Tg$converged],
    d$Tnwb$failure_reason[!d$Tnwb$converged])
  delta <- function(component) {
    same <- !is.na(current$value[[component]]) & !is.na(baseline$value[[component]])
    if (any(same)) max(abs(current$value[[component]][same] - baseline$value[[component]][same])) else NA_real_
  }
  data.frame(residual_tolerance = limit, accepted_rows = sum(accepted),
    rejected_rows = sum(!accepted), Tg_failures = sum(!d$Tg$converged),
    Tnwb_failures = sum(!d$Tnwb$converged),
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
    row.names = NULL)
}

summary <- do.call(rbind, lapply(limits, summarize))
print(summary, row.names = FALSE)
output <- Sys.getenv("BENCHMARK_OUTPUT", "")
if (nzchar(output)) utils::write.csv(summary, output, row.names = FALSE)
