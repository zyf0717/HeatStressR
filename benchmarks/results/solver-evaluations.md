# Solver evaluation baseline

The recorded scenarios cover daytime, nighttime, zero/high radiation, low/high
wind, saturated/dry air, the globe-clipping regression case, and two hourly
representative rows. `evaluations` is the number of fixed-point residual
evaluations; scalar fallbacks are counted separately. The batch residual is
bounded by solver tolerance for converged rows.

The clipping case is intentionally outside the removed `tas + 10` limit and is
now resolved by adaptive scalar bracketing when the batch path falls back.
