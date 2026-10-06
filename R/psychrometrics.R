# Model-specific saturation laws, all with Celsius input and hPa output.
.magnus_coefficients <- function(tas) {
  list(a = ifelse(tas < 0, 17.856, 17.368),
       b = ifelse(tas < 0, 245.52, 238.83),
       c = ifelse(tas < 0, 6.108, 6.107))
}

.saturation_vapour_pressure <- function(tas, formulation = "dosseger") {
  switch(formulation,
    dosseger = {
      p <- .magnus_coefficients(tas)
      p$c * exp(p$a * tas / (p$b + tas))
    },
    buck = 1.004 * 6.1121 * exp(17.502 * tas / (tas + 240.97)),
    bernard = 6.106 * exp(17.27 * tas / (237.3 + tas)),
    stop("Unknown saturation-pressure formulation", call. = FALSE))
}

.vapour_pressure_hpa <- function(tas, hurs) {
  hurs / 100 * .saturation_vapour_pressure(tas)
}

.relative_humidity_percent <- function(tas, dewp) {
  # The inherited Dosseger pair selects coefficients by air temperature.
  p <- .magnus_coefficients(tas)
  values <- 100 * exp(p$a * dewp / (p$b + dewp) - p$a * tas / (p$b + tas))
  values[!is.finite(values)] <- NA_real_
  pmin(100, values)
}

.dew_point_c <- function(tas, hurs) {
  p <- .magnus_coefficients(tas)
  log_ratio <- log(hurs / 100) + p$a * tas / (p$b + tas)
  result <- p$b * log_ratio / (p$a - log_ratio)
  result[which(hurs == 0)] <- -Inf
  result[which(hurs == 100)] <- tas[which(hurs == 100)]
  result
}

# Liljegren heat-balance kernels use Buck over liquid water in Kelvin.
esat <- function(Tk) .saturation_vapour_pressure(Tk - 273.15, "buck")
