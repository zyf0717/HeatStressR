# Liljegren unresolved-row characterization

With independent clock-sine radiation, the deterministic 100,000-row batch
workload produced 3,502 Tg `unbracketed` failures. With radiation derived from
positive solar elevation, it produces zero unresolved components. The prior
failures were therefore a synthetic radiation–solar-geometry mismatch, not
unbracketed physical roots under internally consistent forcing. The unresolved
diagnostic benchmark emits each row's input,
zenith angle, initial/final bracket, endpoint residuals, candidate root,
fallback metadata, and scalar fallback result when `BENCHMARK_OUTPUT` is set.
The internally consistent 100,000-row run records 503 near-horizon
`radiation > 15 && zenith > 1.54` rows in
`liljegren-solar-geometry.csv`; these are diagnostic flags, not solver failures.
