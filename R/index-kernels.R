.heat_index <- function(tas, hurs) {
  tasf <- tas * 1.8 + 32
  result_simple <- 0.5 * (tasf + 61 + (tasf - 68) * 1.2 + hurs * 0.094)
  result <- (result_simple + tasf) / 2
  regression_idx <- which(result >= 80)

  if (length(regression_idx)) {
    tasf_i <- tasf[regression_idx]
    hurs_i <- hurs[regression_idx]
    tasf2 <- tasf_i * tasf_i
    hurs2 <- hurs_i * hurs_i
    result_i <- -42.379 + 2.04901523 * tasf_i + 10.14333127 * hurs_i -
      0.22475541 * tasf_i * hurs_i - 6.83783e-3 * tasf2 -
      5.481717e-2 * hurs2 + 1.22874e-3 * tasf2 * hurs_i +
      8.5282e-4 * tasf_i * hurs2 - 1.99e-6 * tasf2 * hurs2
    result[regression_idx] <- result_i

    adjustment1_idx <- regression_idx[which(
      tasf_i >= 80 & tasf_i <= 112 & hurs_i <= 13
    )]
    if (length(adjustment1_idx)) {
      adjustment1 <- (13 - hurs[adjustment1_idx]) / 4 * sqrt(
        (17 - abs(tasf[adjustment1_idx] - 95)) / 17
      )
      result[adjustment1_idx] <- result[adjustment1_idx] - adjustment1
    }

    adjustment2_idx <- regression_idx[which(
      tasf_i >= 80 & tasf_i <= 87 & hurs_i > 85
    )]
    if (length(adjustment2_idx)) {
      adjustment2 <- (hurs[adjustment2_idx] - 85) / 10 *
        ((87 - tasf[adjustment2_idx]) / 5)
      result[adjustment2_idx] <- result[adjustment2_idx] + adjustment2
    }
  }

  (result - 32) / 1.8
}

.wbt_stull <- function(tas, hurs) {
  tas * atan(0.151977 * sqrt(hurs + 8.313659)) + atan(tas + hurs) -
    atan(hurs - 1.676331) + 0.00391838 * (hurs * sqrt(hurs)) *
    atan(0.023101 * hurs) - 4.686035
}
