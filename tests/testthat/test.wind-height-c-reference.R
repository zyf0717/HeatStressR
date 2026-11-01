# Independent verification of wind_2m_liljegren() against the retained
# Liljegren v1.1 C source (wbgt.c.original). The harness extracts stab_srdt()
# and est_wind_speed() verbatim from the retained file and compiles them, so
# the stability table, exponent tables, MIN_SPEED floor and float arithmetic
# under test are the original ones.
#
# Solar normalization is matched by construction: the C pipeline evaluates the
# radiation class on its internally normalized solar value
# (min(solar/toasolar, 0.85) * toasolar). The harness feeds the class lookup
# the same fixture value the R estimator sees, and every fixture value is at
# most 925 W/m2, which is at most 0.85 * top-of-atmosphere irradiance near
# local noon in low latitudes (toasolar ~ 1367 W/m2), so a full-pipeline C
# run at such a time/location applies the identity normalization to these
# fixtures.
#
# Rows with zspeed == 2 are never compared: the original leaves its
# estimated-speed output unwritten there (documented undefined-output defect,
# see lwbgt docs/DEVIATIONS.md). The R pass-through at 2 m is covered by
# test.wind-height.R instead.

srdt_c_harness <- function() {
  src <- path.expand("~/repos/lwbgt/upstream/wbgt.c.original")
  cc <- Sys.which("cc")
  if (!nzchar(cc) || !file.exists(src)) return(NULL)
  lines <- readLines(src, warn = FALSE)
  start <- grep("^float est_wind_speed\\(", lines)
  stop_fn <- grep("^int stab_srdt\\(", lines)
  if (length(start) != 1L || length(stop_fn) != 1L || stop_fn < start) return(NULL)
  extracted <- paste(lines[start:length(lines)], collapse = "\n")
  # Sanity: the extraction must contain both function bodies and nothing
  # before est_wind_speed() in the retained file.
  if (!grepl("lsrdt[6][8]", extracted, fixed = TRUE)) return(NULL)
  dir <- tempfile("srdt-c-")
  dir.create(dir)
  harness <- file.path(dir, "srdt_harness.c")
  writeLines(c(
    "#include <stdio.h>",
    "#include <math.h>",
    "#define REF_HEIGHT 2.0",
    "#define MIN_SPEED 0.13",
    "#define max(a,b) ((a) > (b) ? (a) : (b))",
    "/* --- verbatim from wbgt.c.original --- */",
    extracted,
    "/* --- end verbatim --- */",
    "int main(void) {",
    "  int daytime, urban, cls;",
    "  float speed, solar, dT, zspeed, est;",
    "  while (scanf(\"%d %f %f %f %f %d\", &daytime, &speed, &solar,",
    "      &dT, &zspeed, &urban) == 6) {",
    "    cls = stab_srdt(daytime, speed, solar, dT);",
    "    est = est_wind_speed(speed, zspeed, cls, urban);",
    "    printf(\"%d %.9g\\n\", cls, est);",
    "  }",
    "  return 0;",
    "}"), harness)
  bin <- file.path(dir, "srdt_harness")
  status <- suppressWarnings(system2(cc,
    c("-O2", "-w", "-o", shQuote(bin), shQuote(harness), "-lm"),
    stdout = FALSE, stderr = FALSE))
  if (status != 0L) return(NULL)
  bin
}

srdt_c_reference <- function(bin, cases) {
  # cases: data.frame with daytime (0/1), speed, solar, dT, zspeed, urban.
  in_path <- tempfile("srdt-in-")
  writeLines(with(cases, paste(daytime, speed, solar, dt, zspeed, urban)),
    in_path)
  out <- system2(bin, stdin = in_path, stdout = TRUE)
  parsed <- strsplit(out[nzchar(trimws(out))], " ", fixed = TRUE)
  data.frame(stability_class = vapply(parsed, function(x) as.integer(x[1]),
    0L, USE.NAMES = FALSE),
    est_speed = vapply(parsed, function(x) as.numeric(x[2]), 0,
      USE.NAMES = FALSE),
    stringsAsFactors = FALSE)
}

# Float-precision caveat: the C reference computes in float (pow in double,
# result rounded to float); the R estimator uses double. Agreement is
# therefore asserted at a relative tolerance of 1e-6, well above float
# rounding (~1e-7) and far below any class-boundary effect.
SRDT_C_TOLERANCE <- 1e-6

test_that("compiled C reference harness is available", {
  bin <- srdt_c_harness()
  skip_if(is.null(bin),
    "compiled Liljegren v1.1 reference (cc + wbgt.c.original) unavailable")
  expect_true(nzchar(bin))
})

test_that("SRDT estimator matches the compiled C reference at class boundaries", {
  bin <- srdt_c_harness()
  skip_if(is.null(bin),
    "compiled Liljegren v1.1 reference (cc + wbgt.c.original) unavailable")

  zspeeds <- c(4, 10, 50)
  day <- expand.grid(speed = c(1.99, 2, 2.99, 3, 4.99, 5, 5.99, 6),
    solar = c(174.99, 175, 674.99, 675, 924.99, 925),
    urban = c(0, 1), zspeed = zspeeds,
    stringsAsFactors = FALSE)
  day$daytime <- 1L
  day$dt <- 0
  night <- expand.grid(speed = c(1.99, 2, 2.49, 2.5),
    dt = c(-1, 0, 1), urban = c(0, 1), zspeed = zspeeds,
    stringsAsFactors = FALSE)
  night$daytime <- 0L
  night$solar <- 0
  calm <- expand.grid(speed = c(0, 0.01, 0.05, 0.06),
    daytime = c(0L, 1L), urban = c(0, 1), zspeed = zspeeds,
    stringsAsFactors = FALSE)
  calm$solar <- 500
  calm$dt <- -1
  cases <- rbind(day, night, calm)[c("daytime", "speed", "solar", "dt",
    "zspeed", "urban")]

  ref <- srdt_c_reference(bin, cases)
  expect_equal(nrow(ref), nrow(cases))
  # The fixture grid must exercise all six SRDT classes and the calm floor.
  expect_equal(sort(unique(ref$stability_class)), 1:6)
  expect_true(any(abs(ref$est_speed - 0.13) < SRDT_C_TOLERANCE))

  est <- wind_2m_liljegren(cases$speed, cases$zspeed, cases$solar,
    cases$daytime == 1L, cases$dt, cases$urban == 1L, diagnostics = TRUE)
  expect_identical(est$stability_class, ref$stability_class)
  expect_equal(est$wind_2m, ref$est_speed, tolerance = SRDT_C_TOLERANCE)
})

test_that("boundary rows just below and at each threshold agree with C", {
  bin <- srdt_c_harness()
  skip_if(is.null(bin),
    "compiled Liljegren v1.1 reference (cc + wbgt.c.original) unavailable")

  cases <- data.frame(
    daytime = c(1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1,
      0, 0, 0, 0, 0, 0, 0, 0, 0),
    speed = c(1.99, 2, 2.99, 3, 4.99, 5, 5.99, 6,
      rep(4, 6),
      1.99, 1.99, 2, 2, 2.49, 2.49, 2.5, 2.5, 1.5),
    solar = c(rep(500, 8), 174.99, 175, 674.99, 675, 924.99, 925,
      rep(0, 9)),
    dt = c(rep(0, 14), -1, 0, -1, 0, -1, 0, -1, 0, -0.001),
    zspeed = rep(10, 23),
    urban = rep(c(0L, 1L), length.out = 23))

  ref <- srdt_c_reference(bin, cases)
  est <- wind_2m_liljegren(cases$speed, cases$zspeed, cases$solar,
    cases$daytime == 1L, cases$dt, cases$urban == 1L, diagnostics = TRUE)
  expect_identical(est$stability_class, ref$stability_class)
  expect_equal(est$wind_2m, ref$est_speed, tolerance = SRDT_C_TOLERANCE)
})
