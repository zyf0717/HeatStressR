# Liljegren inputs and scope

Return to the [package README](https://github.com/zyf0717/HeatStressR#readme).

## Physical controls

`pressure` accepts one value or a vector aligned with the meteorological rows;
the default is 1010 hPa. Other defaults are `surface_albedo = 0.45`,
`globe_diameter = 0.0508`, and `min_wind_speed = 0.13`.

`radiation` is total downwelling shortwave radiation. `direct_fraction`
specifies the direct share, `direct / (direct + diffuse)`, and accepts one
value or a row-aligned vector. It defaults to `0.8`; retain that default when
only total shortwave radiation is available, or supply a measured or
externally derived fraction when direct and diffuse radiation are known.

## Timestamps and intervals

Solar geometry uses latitude, longitude, and timestamp. Use UTC or
timezone-aware `POSIXct` for high-throughput calculations. `POSIXlt`
timestamps and ISO-8601 strings with an offset—for example,
`2024-06-01T20:00:00+08:00` or `2024-06-01T12:00:00Z`—identify instants and
are normalized to UTC when `solar_time = "timestamp"`. ISO-8601 strings are
accepted for convenience but parsed on every call; convert them to `POSIXct`
upstream when performance matters.

HeatStressR evaluates every input at the supplied instant; it does not infer
or apply an interval-average convention. For interval-mean or accumulated
source data, choose the representative instant from source metadata, align all
meteorological inputs to it, and supply that timestamp before calculation.

`solar_time = "timestamp"` uses each full timestamp. `solar_time =
"date_noon"` evaluates each date at 12:00 UTC. The inherited `hour` argument
is retained as a compatibility alias.

## Scope boundary

HeatStressR evaluates aligned meteorological states; it does not perform
meteorological pre-processing. The caller is responsible for:

- choosing the representative instant for interval-mean or accumulated data;
- converting timestamps to UTC or constructing timezone-aware `POSIXct`;
- adjusting wind to the model reference height; and
- deriving and quality-controlling shortwave radiation from cloud cover or
  other source data.

The wrapper returns WBGT, globe temperature, and natural wet-bulb temperature.
It does not expose the original C program's psychrometric wet-bulb or estimated
wind-speed outputs. This keeps the public interface limited to heat-balance
calculation and leaves source-specific processing upstream.

## Validation and numerical controls

Meteorological vectors must be non-empty, equal length, and row-aligned with
`dates`. `lon` and `lat` must be finite geographic coordinates, supplied as
scalars or row-aligned vectors. Repeated coordinate pairs share one
solar-geometry calculation.

`wbgt.Liljegren()` exposes three numerical controls:

- `root_tolerance` controls root-location precision (default `1e-6 K`);
- `residual_tolerance` controls the accepted absolute heat-balance residual
  (default `1e-4 K`; `0 < value <= 0.01`); and
- `dewpoint_tolerance` controls the dewpoint-versus-air-temperature policy
  (default `1e-4 °C`).

Use `diagnostics = TRUE` to investigate invalid inputs or solver failures.
Diagnostic vectors match input length, and `input_status` separates filtered
rows from heat-balance solver failures. Diagnostics are disabled by default to
avoid transferring row-level metadata from PSOCK workers during normal batch
calculations.

Relaxing `residual_tolerance` only accepts an already located finite root; it
does not recover unbracketed or non-finite rows. WBGT is `NA` unless both `Tg`
and `Tnwb` validate, while an independently validated component is retained.
