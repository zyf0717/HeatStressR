# Benchmarking

Return to the [package README](https://github.com/zyf0717/HeatStressR#readme).

`calZenith()` processes date vectors in one pass. `wbgt.Liljegren()`
precomputes aligned zenith angles by coordinate pair and reuses timestamp-only
solar terms for repeated instants. The batch engine is the default because it
vectorizes the dominant numerical solves. It remains single-process unless
`workers > 1`; PSOCK startup can outweigh the benefit of additional workers for
small inputs.

Performance depends on input size, coordinate reuse, worker count, and local
hardware. Measure the current release on the target workload with the
reproducible harness:

```sh
Rscript benchmarks/benchmark-vectorization.R
Rscript benchmarks/benchmark-liljegren-e2e.R
Rscript benchmarks/benchmark-liljegren-parallel.R
Rscript benchmarks/benchmark-liljegren-tolerance-sensitivity.R
```

Worker-count benchmarks hold total input rows fixed for every comparison. They
measure strong scaling across parallel-process counts rather than throughput
under increasing work.

Timed benchmarks use `diagnostics = FALSE`; diagnostic validation is run
separately when required. See the [benchmark documentation](https://github.com/zyf0717/HeatStressR/blob/master/benchmarks/README.md)
for workload definitions, result locations, and interpretation.
