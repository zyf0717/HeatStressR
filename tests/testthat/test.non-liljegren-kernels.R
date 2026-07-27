legacy_vapour_pressure <- function(tas, hurs) {
  tas <- 10 * tas
  hurs[hurs > 100] <- 100
  vapour_pressure <- rep(NA, length(tas))
  water <- which(tas >= 0)
  ice <- which(tas < 0)
  vapour_pressure[water] <- hurs[water] * 0.06107 * exp(
    17.368 * tas[water] / (2388.3 + tas[water])
  )
  vapour_pressure[ice] <- hurs[ice] * 0.06108 * exp(
    17.856 * tas[ice] / (2455.2 + tas[ice])
  )
  vapour_pressure
}

test_that("tashurs2vap.pres retains public clamping across temperature phases", {
  tas <- c(-40L, -0.1, 0L, 0.1, 35, NA_real_)
  hurs <- c(0L, 50, 100, 101, NA_real_, 40)
  expected <- legacy_vapour_pressure(tas, hurs)

  expect_equal(tashurs2vap.pres(tas, hurs), expected, tolerance = 1e-12)
  named_tas <- c(north = -1, south = 1)
  named_hurs <- c(north = 50, south = 75)
  expect_equal(tashurs2vap.pres(named_tas, named_hurs),
    legacy_vapour_pressure(named_tas, named_hurs), tolerance = 1e-12)
  expect_type(tashurs2vap.pres(integer(), integer()), "double")
  expect_length(tashurs2vap.pres(integer(), integer()), 0)
  expect_equal(tashurs2vap.pres(1:2, 50),
    legacy_vapour_pressure(1:2, 50), tolerance = 1e-12)
})

test_that("vapour-pressure dependent indices retain their public outputs", {
  tas <- c(-10, 0, 20, NA_real_)
  hurs <- c(40, 60, 80, 50)
  wind <- c(1, 2, 3, 1)
  vp <- legacy_vapour_pressure(tas, hurs)

  expect_equal(apparentTemp(tas, hurs, wind), tas + 0.33 * vp - 0.7 * wind - 4,
    tolerance = 1e-12)
  expect_equal(humidex(tas, hurs), tas + 5 / 9 * (vp - 10), tolerance = 1e-12)
  expect_equal(swbgt(tas, hurs), 0.567 * tas + 0.216 * vp + 3.38,
    tolerance = 1e-12)
  expect_error(humidex(20, 101), "greater than 100")
})

test_that("heat_indices matches individual indices and validates required inputs", {
  tas <- c(-5, 10, 25, 35)
  hurs <- c(50, 60, 70, 80)
  wind <- c(1, 2, 3, 4)
  dewp <- c(-8, 5, 18, 28)
  fused <- heat_indices(tas, hurs, wind = wind)

  expect_s3_class(fused, "data.frame")
  expect_identical(names(fused), c(
    "wbt", "swbgt", "apparentTemp", "effectiveTemp", "humidex", "discomInd", "hi"
  ))
  expect_equal(fused$wbt, wbt.Stull(tas, hurs))
  expect_equal(fused$swbgt, swbgt(tas, hurs))
  expect_equal(fused$apparentTemp, apparentTemp(tas, hurs, wind))
  expect_equal(fused$effectiveTemp, effectiveTemp(tas, hurs, wind))
  expect_equal(fused$humidex, humidex(tas, hurs))
  expect_equal(fused$discomInd, discomInd(tas, hurs))
  expect_equal(fused$hi, hi(tas, hurs))

  bernard <- heat_indices(tas, hurs, dewp = dewp, indices = "wbgt.Bernard")
  expect_equal(bernard$wbgt.Bernard, wbgt.Bernard(tas, dewp)$data)
  expect_error(heat_indices(tas, hurs, indices = "apparentTemp"), "same length")
  expect_error(heat_indices(tas, hurs, indices = "wbgt.Bernard"), "same length")
  expect_error(heat_indices(tas, hurs, indices = c("hi", "hi")), "unique")
})

test_that("dewp2hurs preserves values and rejects unaligned inputs", {
  tas <- c(-10, 0, 20, NA_real_)
  dewp <- c(-12, -2, 10, 5)
  expected <- c(
    100 * exp(17.856 * dewp[1] / (245.52 + dewp[1]) - 17.856 * tas[1] / (245.52 + tas[1])),
    100 * exp(17.368 * dewp[2] / (238.83 + dewp[2]) - 17.368 * tas[2] / (238.83 + tas[2])),
    100 * exp(17.368 * dewp[3] / (238.83 + dewp[3]) - 17.368 * tas[3] / (238.83 + tas[3])),
    NA_real_
  )
  expect_equal(dewp2hurs(tas, dewp), expected, tolerance = 1e-12)
  expect_equal(dewp2hurs(1:2, 1), c(dewp2hurs(1, 1), NA_real_))
})
