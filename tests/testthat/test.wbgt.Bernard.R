####################################################################
#
# Package HeatStressR
#
# Test for heat stress indices computation
#
###################################################################
library("HeatStressR")

legacy_wbgt_bernard <- function(tas, dewp, tolerance = 1e-4,
                                noNAs = TRUE, swap = FALSE) {
  c1 <- 6.106
  c2 <- 17.27
  c3 <- 237.3
  c4 <- 1556
  c5 <- 1.484
  c6 <- 1010
  Tpwb <- rep(NA_real_, length(tas))
  residual <- function(Tpwb, tasi, edi) {
    abs(c4 * edi - c5 * edi * Tpwb - c4 * c1 * exp((c2 * Tpwb) / (c3 + Tpwb)) +
      c5 * c1 * exp((c2 * Tpwb) / (c3 + Tpwb)) * Tpwb + c6 * (tasi - Tpwb))
  }

  trivial <- abs(tas - dewp) < tolerance
  Tpwb[which(trivial)] <- tas[which(trivial)]
  xmask <- !is.na(tas + dewp) & !trivial
  if (noNAs && swap) {
    tas_tmp <- pmax(tas, dewp)
    dewp <- pmin(tas, dewp)
    tas <- tas_tmp
  } else if (noNAs && !swap) {
    noway <- (dewp - tas) > tolerance
    xmask <- xmask & !noway
    Tpwb[which(noway)] <- tas[which(noway)]
  } else if (!noNAs) {
    xmask <- xmask & tas >= dewp
  }

  ed <- c1 * exp((c2 * dewp) / (c3 + dewp))
  for (i in which(xmask)) {
    Tpwb[i] <- stats::optimize(
      residual, range(tas[i] + 1, dewp[i] - 1), tasi = tas[i], edi = ed[i],
      tol = tolerance
    )$minimum
  }
  list(Tpwb = Tpwb, data = 0.67 * Tpwb + 0.33 * tas)
}

test_that("test if the wbgt.Bernard function computes WBGTshade properly",{
  data("data_obs", envir = environment())
  tas <- data_obs$tasmean
  hurs <- data_obs$hurs
  dewp <- data_obs$dewp
  wind <- data_obs$wind
  solar <- data_obs$solar
  dates <- data_obs$Dates

  data("data_wbgt.Bernard", envir = environment())
  WBGT.shade <- data_wbgt.Bernard$data
  Tpwb <- data_wbgt.Bernard$Tpwb
  
  WBGTshade.new <- wbgt.Bernard(tas,dewp)
  
  expect_equal(WBGTshade.new$data,WBGT.shade, tolerance = 1e-3)
  
  expect_equal(WBGTshade.new$Tpwb,Tpwb, tolerance = 1e-3)
})

test_that("wbgt.Bernard preserves missing input row positions", {
  result <- wbgt.Bernard(
    tas = c(25, NA_real_, 30),
    dewp = c(20, 15, NA_real_)
  )

  expect_identical(is.na(result$Tpwb), c(FALSE, TRUE, TRUE))
  expect_identical(is.na(result$data), c(FALSE, TRUE, TRUE))
})

test_that("wbgt.Bernard matches the legacy optimizer on representative grids", {
  data("data_obs", envir = environment())
  adversarial <- expand.grid(tas = seq(-50, 80, by = 10), depression = c(1, 5, 20))
  adversarial$dewp <- adversarial$tas - adversarial$depression
  grids <- list(
    list(tas = data_obs$tasmean, dewp = data_obs$dewp),
    list(tas = adversarial$tas, dewp = adversarial$dewp)
  )

  for (grid in grids) {
    legacy <- legacy_wbgt_bernard(grid$tas, grid$dewp)
    vectorized <- wbgt.Bernard(grid$tas, grid$dewp)
    finite <- is.finite(legacy$Tpwb) & is.finite(vectorized$Tpwb)
    expect_lte(max(abs(legacy$Tpwb[finite] - vectorized$Tpwb[finite])), 1e-4)
    expect_equal(vectorized$data, legacy$data, tolerance = 1e-4)
  }
})

test_that("wbgt.Bernard retains legacy noNAs, swap, trivial, and NA semantics", {
  tas <- c(30, 30, 30, 30, NA_real_, 30, 30)
  dewp <- c(20, 30, 35, 30.00005, 20, NA_real_, 10)

  for (noNAs in c(TRUE, FALSE)) {
    for (swap in c(TRUE, FALSE)) {
      legacy <- legacy_wbgt_bernard(tas, dewp, noNAs = noNAs, swap = swap)
      vectorized <- wbgt.Bernard(tas, dewp, noNAs = noNAs, swap = swap)
      expect_identical(is.na(vectorized$Tpwb), is.na(legacy$Tpwb))
      expect_identical(is.na(vectorized$data), is.na(legacy$data))
      expect_equal(vectorized$Tpwb, legacy$Tpwb, tolerance = 1e-4)
      expect_equal(vectorized$data, legacy$data, tolerance = 1e-4)
    }
  }
})
