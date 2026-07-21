scalar_domain_result <- function(cases, component) {
  vapply(seq_len(nrow(cases)), function(i) {
    x <- cases[i, ]
    solution <- if (identical(component, "Tg")) {
      suppressWarnings(HeatStress:::fTg_solution(x$tas, 50, x$Pair, x$wind,
        0.1, x$radiation, x$propDirect, x$zenith, x$SurfAlbedo))
    } else {
      suppressWarnings(HeatStress:::fTnwb_solution(x$tas, x$dewp, 50, x$Pair,
        x$wind, 0.1, x$radiation, x$propDirect, x$zenith, x$irad,
        x$SurfAlbedo))
    }
    if (solution$converged) solution$root else NA_real_
  }, numeric(1))
}

test_that("WBGT direct solvers agree over a deterministic domain matrix", {
  cases <- wbgt_domain_cases()
  for (component in c("Tg", "Tnwb")) {
    scalar <- scalar_domain_result(cases, component)
    for (Pair in unique(cases$Pair)) {
      idx <- which(cases$Pair == Pair)
      x <- cases[idx, ]
      batch <- if (identical(component, "Tg")) {
        HeatStress:::fTg_batch(x$tas, rep(50, nrow(x)), Pair, x$wind, 0.1,
          x$radiation, x$propDirect, x$zenith, x$SurfAlbedo)
      } else {
        HeatStress:::fTnwb_batch(x$tas, x$dewp, rep(50, nrow(x)), Pair,
          x$wind, 0.1, x$radiation, x$propDirect, x$zenith, x$irad,
          x$SurfAlbedo)
      }
      expect_false(any(is.infinite(batch)))
      expect_identical(is.na(batch), is.na(scalar[idx]))
      finite <- !is.na(batch)
      expect_true(all(attr(batch, "converged")[finite]))
      expect_lte(max(abs(attr(batch, "final_residual")[finite])), 1e-4)
      expect_equal(as.numeric(batch), scalar[idx], tolerance = 1e-4)
      expect_true(all(attr(batch, "lower")[finite] <= batch[finite] + 273.15))
      expect_true(all(batch[finite] + 273.15 <= attr(batch, "upper")[finite]))
    }
  }
})

test_that("WBGT batch solver results are invariant to row order", {
  cases <- wbgt_domain_cases(48L)
  forward <- HeatStress:::fTg_batch(cases$tas, rep(50, nrow(cases)), 1010,
    cases$wind, 0.1, cases$radiation, cases$propDirect, cases$zenith,
    cases$SurfAlbedo)
  reverse <- HeatStress:::fTg_batch(rev(cases$tas), rep(50, nrow(cases)), 1010,
    rev(cases$wind), 0.1, rev(cases$radiation), rev(cases$propDirect),
    rev(cases$zenith), rev(cases$SurfAlbedo))
  expect_equal(as.numeric(forward), as.numeric(rev(reverse)), tolerance = 1e-4)
})

test_that("WBGT wrapper engines agree over deterministic matrix samples", {
  cases <- wbgt_domain_cases(48L)
  dates <- as.POSIXct("2024-06-01 00:00:00", tz = "UTC") +
    seq_len(nrow(cases)) * 3600
  scalar <- suppressWarnings(wbgt.Liljegren(cases$tas, cases$dewp, cases$wind,
    cases$radiation, dates, lon = 0, lat = 0, hour = TRUE, engine = "scalar"))
  batch <- suppressWarnings(wbgt.Liljegren(cases$tas, cases$dewp, cases$wind,
    cases$radiation, dates, lon = 0, lat = 0, hour = TRUE, engine = "batch"))
  for (component in c("data", "Tg", "Tnwb")) {
    expect_identical(is.na(batch[[component]]), is.na(scalar[[component]]))
    expect_equal(batch[[component]], scalar[[component]], tolerance = 1e-4)
  }
})
