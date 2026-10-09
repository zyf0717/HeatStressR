# Install the numerical reference version in a caller-selected isolated library.
# Usage: Rscript tools/install-reference-dependencies.R /path/to/library
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop("Supply one isolated R library path")
lib <- args[[1L]]
dir.create(lib, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(lib, .libPaths()))
options(timeout = max(120, getOption("timeout")))
if (!requireNamespace("Rcpp", quietly = TRUE))
  install.packages("Rcpp", lib = lib, repos = "https://cloud.r-project.org")
# Try the current release path first, then the CRAN archive if superseded.
urls <- c("https://cloud.r-project.org/src/contrib/heatindex_0.0.2.tar.gz",
  "https://cloud.r-project.org/src/contrib/Archive/heatindex/heatindex_0.0.2.tar.gz")
archive <- tempfile(fileext = ".tar.gz")
installed <- FALSE
for (url in urls) {
  ok <- tryCatch({ utils::download.file(url, archive, mode = "wb", quiet = TRUE); TRUE },
    error = function(e) FALSE)
  if (!ok) next
  install.packages(archive, lib = lib, repos = NULL, type = "source")
  installed <- requireNamespace("heatindex", quietly = TRUE) &&
    as.character(utils::packageVersion("heatindex")) == "0.0.2"
  if (installed) break
}
unlink(archive)
if (!installed) stop("Could not install heatindex 0.0.2")
