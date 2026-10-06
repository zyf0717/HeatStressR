test_that("canonical Liljegren returns numeric values and optional components", {
  time <- as.POSIXct("2024-06-01 12:00:00",tz="UTC")
  x <- wbgt_liljegren(30,20,1,700,time,0,15,diagnostics=TRUE)
  expect_equal(wbgt_liljegren(30,20,1,700,time,0,15),x$values)
  expect_identical(names(x$components),c("tnwb","tg"))
  expect_equal(x$values,0.7*x$components$tnwb+0.2*x$components$tg+0.1*30)
  expect_true(x$diagnostics$rows$converged)
  for (solver in x$diagnostics$solver[c("Tg","Tnwb")]) {
    expect_lte(abs(solver$final_residual),solver$residual_tolerance)
  }
  expect_error(wbgt_liljegren(30,20,1,700,time,0,15,control=list(tolerance=1e-4)),"supported")
  expect_error(wbgt_liljegren(30,20,1,700,time,0,15,workers=0),"workers")
  empty <- wbgt_liljegren(numeric(),numeric(),numeric(),numeric(),
    as.POSIXct(character(),tz="UTC"),0,15,diagnostics=TRUE)
  expect_identical(empty$values,numeric())
  expect_equal(nrow(empty$diagnostics$rows),0)
})

test_that("finite numerical failures differ from invalid observations", {
  time <- as.POSIXct("2024-06-01 12:00:00",tz="UTC")
  expect_warning(x <- wbgt_liljegren(30,20,1,700,time,0,15,
    control=list(root_tolerance=10,residual_tolerance=1e-20),diagnostics=TRUE),"solver_failure=1")
  expect_true(is.na(x$values))
  expect_identical(x$diagnostics$rows$input_status,"valid")
  expect_false(x$diagnostics$rows$converged)
  expect_warning(y <- wbgt_liljegren(30,20,-1,700,time,0,15,diagnostics=TRUE),"invalid=1")
  expect_identical(y$diagnostics$rows$input_reason,"wind_2m")
  expect_false(y$diagnostics$solver$attempted)
})

test_that("canonical Liljegren maintains ordered PSOCK parity for mixed rows", {
  skip_if(HeatStressR:::max_liljegren_workers()<2L,"requires two permitted CPUs")
  time <- as.POSIXct("2024-06-01 12:00:00",tz="UTC")+0:3*3600
  run <- function(workers,diagnostics) suppressWarnings(wbgt_liljegren(
    c(30,31,32,33),c(20,35,22,23),c(1,2,-1,1),c(700,750,800,650),time,
    c(0,10,20,30),15,workers=workers,diagnostics=diagnostics))
  one <- run(1L,TRUE)
  two <- run(2L,TRUE)
  expect_identical(one$values,two$values)
  expect_identical(one$components,two$components)
  expect_identical(one$diagnostics$rows,two$diagnostics$rows)
  two$diagnostics$solver$workers <- 1L
  two$diagnostics$solver$requested_workers <- 1L
  expect_identical(one,two)
  expect_identical(run(1L,FALSE),run(2L,FALSE))
})
