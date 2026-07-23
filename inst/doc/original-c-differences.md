# Differences from the original Liljegren C implementation

Return to the [package README](https://github.com/zyf0717/HeatStressR#readme).

HeatStressR implements the Liljegren heat-balance model; it is not a
bitwise-compatible port of the
[original C source](https://raw.githubusercontent.com/mdljts/wbgt/master/src/wbgt.c.original).
The differences below describe current HeatStressR behavior and do not claim
it improves on or supersedes the original implementation.

HeatStressR supports instantaneous inputs only. It does not use an
averaging-period argument to shift solar time. For interval data, the caller
must choose a representative instant and align all inputs before calculation.

| Area | HeatStressR | Original C program | Consequence |
| --- | --- | --- | --- |
| Wind-height adjustment | Accepts scalar or row-aligned pressure; supplied wind is assumed to be at the reference height. | Can transform wind from another height using stability, temperature gradient, and urban/rural inputs. | Adjust non-reference-height wind externally before calling the wrapper. |
| Solar geometry and time | Uses the supplied instant, timezone-aware timestamps, latitude, longitude, and equation of time. | Uses local standard time, GMT offset, input averaging period, and its own solar-position routine. | Convert local observations to UTC or provide timezone-aware timestamps; align interval data externally before calculation. |
| Irradiance partitioning | Retains supplied daytime radiation and accepts a scalar or row-aligned `direct_fraction` (default `0.8`). | Caps irradiance against top-of-atmosphere solar flux and derives direct fraction from normalized irradiance. | Cloudy, miscalibrated, and near-horizon forcing can produce different `Tg` and `Tnwb`; supply an externally derived fraction when available. |
| Root solving and failures | Uses adaptive bracketing, residual validation, `NA` failures, preserved valid components, and optional diagnostics/batch fallback. | Uses damped fixed-point iteration (50-iteration limit, `0.02 K` convergence test) and reports `-9999` when a component fails. | Numerical behavior, failure boundaries, and error outputs deliberately differ. |
| Output surface | Returns WBGT, `Tg`, and `Tnwb`. | Also returns psychrometric wet-bulb temperature and estimated wind speed. | The wrapper does not expose the full original-program output set. |

For cross-implementation validation, match pressure, wind height, time
convention, and radiation treatment. Agreement on one weather series does not
establish interchangeability.
