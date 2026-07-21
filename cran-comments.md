## Test environments

- Local: macOS Tahoe 26.5.2, R 4.6.1, aarch64-apple-darwin25.4.0
- Configured GitHub Actions matrix: Ubuntu (R 4.1, oldrel-1, release, devel),
  Windows (release), and macOS (release)
- External builder checks: not run; require maintainer submission

## R CMD check results

- `R CMD check --as-cran HeatStressR_2.1.0.tar.gz`
- `R CMD check --as-cran --run-donttest HeatStressR_2.1.0.tar.gz`

0 errors | 0 warnings | 1 note

The only note is:

- New submission.

External checks must be added here after their completion.

## New submission

This is the intended first CRAN submission of HeatStressR.

HeatStressR is an independently maintained fork of the GitHub-hosted
HeatStress package. Its package name distinguishes this release from the
upstream project. The public function interface is retained, while the
Liljegren WBGT path is implemented in R with explicit numerical controls,
row-level diagnostics, and optional batch execution.

CRAN checks package portability and software quality. Users remain responsible
for matching methodological assumptions to their application; this package is
not a bitwise-compatible replacement for the original Liljegren C program, and
differences from other implementations are expected. This is not a claim that
HeatStressR improves on or supersedes the original Liljegren implementation.

## Downstream dependencies

No reverse dependencies are known for this intended first submission.

## Remaining pre-submission steps

- Submit the final tarball to win-builder (release and devel).
- Run macbuilder and/or R-hub checks if desired.
- Submit through the CRAN web form and confirm the maintainer email.
- Update this file with external-check outcomes and respond to CRAN feedback.
