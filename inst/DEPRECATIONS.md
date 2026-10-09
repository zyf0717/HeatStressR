# HeatStressR 2.x compatibility removal manifest

Deprecated since 3.0.0. Removal is planned no earlier than 4.0.0.
All public adapters, argument translations, swapping, legacy time conventions,
and legacy output projections live in `R/compat-v2.R`. The numerical core
never calls deprecated endpoints. `test.core-independence.R` enforces that
boundary by replacing the retired functions with errors.

| Retired endpoint | Replacement |
| --- | --- |
| apparentTemp | apparent_temperature |
| effectiveTemp | effective_temperature |
| discomInd | discomfort_index |
| hi | heat_index_rothfusz |
| swbgt | wbgt_simplified_indoor |
| wbt.Stull | wet_bulb_stull |
| wbgt.Bernard | wbgt_bernard |
| wbgt.Liljegren | wbgt_liljegren |
| dewp2hurs | relative_humidity |
| tashurs2vap.pres | vapour_pressure |
| indexShow | heat_methods |
| calZenith | solar_zenith |
| fTg, fTnwb | wbgt_liljegren(..., diagnostics = TRUE)$components |

The machine-readable endpoint map is `.legacy_endpoints` in the compatibility
file. Registry aliases also include `wbt`, `wbgt_shade`, and `wbgt_sun`.

## Removal procedure

1. Delete `R/compat-v2.R`, `R/deprecation.R`, and `tests/testthat/test.compat-v2.R`.
2. Remove the `wind` formal and its marked `.legacy_bulk_wind()` hook from
   `heat_indices()`. Remove its alias-resolution branch and registry alias
   values. Both integration sites carry `DEPRECATED(v4)` markers.
3. Remove the marked date-only branch from `parse_wall_datetime()` in
   `R/solar-geometry.R`, retaining the datetime parser needed for ISO instants.
   Remove compatibility-only `wind_clamped` and `radiation_clamped` diagnostic
   fields from preprocessing, worker transfer, and result assembly in
   `R/wbgt-parallel.R` and `R/wbgt-core.R`. These fields are always false in v3;
   invalid forcing is rejected. Keep the actual below-horizon adjustment flag.
4. Update the remaining physical reference tests and historical benchmark
   runners that intentionally exercise the legacy interface. Keep their
   scientific parity/boundary tests. Find references with:
   `rg 'wbgt\.Liljegren|wbgt\.Bernard|wbt\.Stull|calZenith|dewp2hurs|fTg\(|fTnwb\(' tests benchmarks`.
5. Update `test.core-independence.R` to check that retired exports are absent,
   rather than mock them. Remove deprecated examples in inherited data help
   and the transitional migration sections.
6. Regenerate roxygen documentation and NAMESPACE. The deprecated help page
   and exports then disappear automatically. Run the full suite and package check.

Keep the scalar scientific solvers: batch fallback still requires them.
`fTg_solution()` and `fTnwb_solution()` are numerical kernels, not deprecated
public adapters. Keep historical author and license notices.
