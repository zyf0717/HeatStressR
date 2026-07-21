#!/usr/bin/env Rscript

# Characterize every unresolved component in the deterministic 100,000-row
# Liljegren workload. Set BENCHMARK_OUTPUT to persist the row-level CSV.

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
result <- suppressWarnings(wbgt.Liljegren(weather$tas, weather$dewp, weather$wind,
  weather$radiation, weather$dates, lon = -5.66, lat = 40.96, hour = TRUE,
  engine = Sys.getenv("LILJEGREN_ENGINE", "batch"), diagnostics = TRUE))
zenith <- HeatStressR:::degToRad(calZenith(weather$dates, -5.66, 40.96, hour = TRUE))

component_rows <- function(name) {
  d <- result$diagnostics[[name]]
  failed <- which(result$diagnostics$attempted & !d$converged)
  fallback.result <- if (is.null(d$fallback_converged)) rep(NA, length(failed)) else
    d$fallback_converged[failed]
  data.frame(row_index = failed, tas = weather$tas[failed], dewp = weather$dewp[failed],
    wind = weather$wind[failed], radiation = weather$radiation[failed],
    date = as.character(weather$dates)[failed], zenith_angle = zenith[failed],
    solar_geometry_mismatch = result$diagnostics$solar_geometry_mismatch[failed],
    failed_component = rep(name, length(failed)), failure_reason = d$failure_reason[failed],
    initial_lower = d$initial_lower[failed], initial_upper = d$initial_upper[failed],
    final_lower = d$final_lower[failed], final_upper = d$final_upper[failed],
    lower_residual = d$lower_residual[failed], upper_residual = d$upper_residual[failed],
    candidate_root = d$candidate_root[failed], candidate_final_residual = d$final_residual[failed],
    batch_fallback_attempted = d$used_fallback[failed],
    scalar_fallback_result = fallback.result, row.names = NULL)
}

solar_geometry_rows <- function() {
  mismatch <- which(result$diagnostics$solar_geometry_mismatch)
  data.frame(row_index = mismatch, tas = weather$tas[mismatch], dewp = weather$dewp[mismatch],
    wind = weather$wind[mismatch], radiation = weather$radiation[mismatch],
    date = as.character(weather$dates)[mismatch], zenith_angle = zenith[mismatch],
    solar_geometry_mismatch = rep(TRUE, length(mismatch)),
    failed_component = rep("solar_geometry", length(mismatch)),
    failure_reason = rep("radiation_gt_15_zenith_gt_1.54", length(mismatch)),
    initial_lower = rep(NA_real_, length(mismatch)), initial_upper = rep(NA_real_, length(mismatch)),
    final_lower = rep(NA_real_, length(mismatch)), final_upper = rep(NA_real_, length(mismatch)),
    lower_residual = rep(NA_real_, length(mismatch)), upper_residual = rep(NA_real_, length(mismatch)),
    candidate_root = rep(NA_real_, length(mismatch)),
    candidate_final_residual = rep(NA_real_, length(mismatch)),
    batch_fallback_attempted = rep(NA, length(mismatch)),
    scalar_fallback_result = rep(NA, length(mismatch)), row.names = NULL)
}

diagnostics <- list(Tg = component_rows("Tg"), Tnwb = component_rows("Tnwb"),
  solar_geometry = solar_geometry_rows())
print(nrow(diagnostics$solar_geometry))
print(table(diagnostics$Tg$failure_reason))
print(table(diagnostics$Tnwb$failure_reason))
print(summary(abs(diagnostics$Tg$candidate_final_residual)))
print(summary(abs(diagnostics$Tnwb$candidate_final_residual)))
output <- Sys.getenv("BENCHMARK_OUTPUT", "")
if (nzchar(output)) utils::write.csv(do.call(rbind, diagnostics), output, row.names = FALSE)
