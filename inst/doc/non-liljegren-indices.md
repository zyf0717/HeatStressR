# Wet bulb, Heat Index and other indices

Use `heat_methods()` for required inputs, reference humidity phases, units and
citations. Standalone canonical methods return numeric vectors; diagnostics
return values, components and row-level status information.

Stull is a fast sea-level wet-bulb approximation with a restricted domain.
Romps is pressure-aware thermodynamic liquid-water wet bulb. Bernard returns
indoor/shade WBGT, with its psychrometric wet-bulb component available through
diagnostics. Natural wet bulb from Liljegren is a different quantity.

`heat_index_rothfusz()` implements the corrected NWS procedure.
`heat_index_lu()` uses the simplified 2026 physiological model through the
external `heatindex` package. Pin the dependency version for reproducibility.

The ABM and indoor simplified WBGT formulas have distinct canonical names,
`wbgt_simplified_abm()` and `wbgt_simplified_indoor()`. Neither models measured
solar radiation or wind. Legacy `swbgt()` represents the indoor formula.

Apparent/effective temperature require wind at 10 m. Humidex and discomfort
index require temperature and RH. Vapour-pressure work is shared in bulk
calls with matching validated inputs and phase conventions.

```r
heat_indices(tas, hurs, wind_10m = wind,
  indices = c("humidex", "heat_index_lu", "apparent_temperature"))
```

Without explicit `indices`, every method supported by supplied inputs is
selected, including numerical methods. Unknown applicability bounds remain
unknown; documented extrapolations are computed and flagged. See
[migration-v3.md](migration-v3.md) for behavior changes.
