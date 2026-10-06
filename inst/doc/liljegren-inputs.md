# Liljegren inputs and scope

`wbgt_liljegren()` evaluates instantaneous meteorological states. Supply air
and dew-point temperature in C, wind at 2 m in m/s, total downwelling shortwave
radiation in W/m2, geographic coordinates in degrees, and timestamps identifying
instants. No wind-height or interval adjustment is performed.

POSIXct/POSIXlt timestamps and offset-bearing ISO-8601 strings are normalized
to UTC. Convert strings upstream for repeated high-throughput calls. Date-only
and unzoned-string conventions are confined to deprecated adapters. Align
interval means or accumulated data to a representative instant using source
metadata before calculation.

`pressure` defaults to 1010 hPa and may be scalar or row-aligned.
`direct_fraction` is direct / (direct + diffuse), default 0.8. Supply a measured
or externally derived fraction when available. `control` contains advanced
physical/numerical settings: root_tolerance=1e-6 K,
residual_tolerance=1e-4 K (at most 0.01), surface_albedo=0.45,
globe_diameter=0.0508 m, and min_wind_speed=0.13 m/s.

Numeric scalars expand. Empty observations return empty results; unequal
non-scalar lengths and malformed controls raise errors. Missing observations
remain NA. Invalid physical inputs, including negative wind/radiation and
non-finite values, produce NA rows and one summary warning.

`dewpoint_policy` caps above-air dew points by default and reports adjustment;
`"na"` rejects those rows, while `"error"` stops the call. Swapping temperatures
is supported only by deprecated compatibility adapters.

Solar forcing is set to zero below the horizon. Diagnostics record that
operation and geometry mismatches. The batch solver uses safeguarded roots,
residual validation and scalar fallback. Complete WBGT requires both component
roots; a validated globe or natural wet-bulb component survives failure of its
partner. Root precision and residual acceptance are independent.

The default return is a numeric WBGT vector. With diagnostics, use `$values`,
`$components$tnwb`, `$components$tg`, `$diagnostics$rows`, and
`$diagnostics$solver`. Rows distinguish invalid input from calculation failure;
solver details retain convergence, residuals, brackets and fallback reasons.

This R model uses the supplied daytime radiation and configurable direct
fraction, rather than the original C program's irradiance capping and derived
partitioning. Match model assumptions when comparing implementations; see
[original-c-differences.md](original-c-differences.md).
