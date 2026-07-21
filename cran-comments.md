## Test environments

- Local: macOS Tahoe 26.5.2, R 4.6.1, aarch64-apple-darwin25.4.0
- Configured GitHub Actions matrix: Ubuntu (R 4.1, oldrel-1, release, devel),
  Windows (release), and macOS (release)
- External builder checks: not run; require maintainer submission

## R CMD check results

- `R CMD check --as-cran --no-manual HeatStressR_2.1.0.tar.gz`:
  0 errors | 0 warnings | 2 notes
- `R CMD check --as-cran --run-donttest --no-manual HeatStressR_2.1.0.tar.gz`:
  0 errors | 0 warnings | 2 notes
- `R CMD check --as-cran HeatStressR_2.1.0.tar.gz`:
  1 error | 1 warning | 4 notes, all cascading from the absence of
  `pdflatex` for the manual

The notes report a new submission and that Pandoc is not installed locally, so
`README.md` and `NEWS` could not be checked. A full `--as-cran` check also
requires a local LaTeX installation; `pdflatex` is not available on this host.
External checks must be added here after their completion.

## New submission

This is the intended first CRAN submission of HeatStressR.

HeatStressR is an independently maintained fork of the GitHub-hosted
HeatStress package. Its package name distinguishes this release from the
upstream project. The public function interface is retained, while the
Liljegren WBGT implementation includes corrected solar geometry, robust root
solving, row-level diagnostics, and optional batch execution.

CRAN checks package portability and software quality. Users remain responsible
for matching methodological assumptions to their application; this package is
not a bitwise-compatible replacement for the original Liljegren C program.

## Downstream dependencies

No reverse dependencies are known for this intended first submission.

## Remaining pre-submission steps

- Submit the final tarball to win-builder (release and devel).
- Run macbuilder and/or R-hub checks if desired.
- Submit through the CRAN web form and confirm the maintainer email.
- Update this file with external-check outcomes and respond to CRAN feedback.
