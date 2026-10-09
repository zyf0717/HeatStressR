# Reference fixture provenance

- `v2-valid.rds`: HeatStressR 2.4.0 at commit `112f43f`, generated before this
  implementation. Covers unaffected valid-input formula outputs and Bernard
  components. Heat Index is excluded because known NWS corrections change it.
- `nws-heat-index.csv`: the published NWS procedure evaluated independently in
  Python by `tools/generate-nws-fixtures.py`. Covers simple averaging,
  regression selection, low/high RH adjustments, and their boundary values.
  Source: https://www.wpc.ncep.noaa.gov/html/heatindex_equation.shtml.
- `heatindex-0.0.2.csv`: direct output of the authors' CRAN R package 0.0.2,
  evaluated by `tools/generate-modern-fixtures.R` without importing HeatStressR.
  Covers 70 combinations of freezing boundaries, 0/100% RH, warm extremes,
  and 700/1010 hPa. Fixture values are Celsius; upstream calculations use
  Kelvin, RH fractions and Pa. Reference repository:
  https://github.com/davidromps/heatindex/tree/ebe4a831c1c01de071c8debf27863f1ad92b5782.

These are frozen implementation fixtures, not empirical measurements.
Upstream algorithm accuracy and adapter numerical agreement are separate
claims. Regeneration is deliberate; normal tests never update fixtures.
