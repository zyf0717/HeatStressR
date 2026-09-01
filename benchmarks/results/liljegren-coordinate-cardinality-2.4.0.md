# Liljegren coordinate-cardinality benchmark

Recorded 2026-09-02 on Linux x86-64 (`x86_64-pc-linux-gnu`) with R 4.6.1 on
an Intel Core i9-13900HK. The comparison uses master commit
`41eca970a0649736d7b7c9633c59e7d8e19e3cf2`, which groups rows by coordinate
pair, and the vectorized HeatStressR 2.4.0 implementation.

Every workload repeats the same 24 timestamps so the benchmark isolates
coordinate projection. The 100,000-row cases use five repetitions; the
1,000,000-row case uses three.

| Rows | Coordinates | Grouped master | 2.4.0 vectorized | Speedup |
| ---: | ---: | ---: | ---: | ---: |
| 100,000 | 1 | 0.044 s | 0.017 s | 2.59x |
| 100,000 | 100 | 0.047 s | 0.015 s | 3.13x |
| 100,000 | 100,000 | 1.258 s | 0.015 s | 83.87x |
| 1,000,000 | 1,000,000 | 16.871 s | 0.206 s | 81.90x |

Peak process RSS measured with `/usr/bin/time -v` fell from 187.1 MiB to
134.3 MiB for the complete 100,000-row matrix and from 583.2 MiB to 264.5 MiB
for 1,000,000 unique coordinates. All outputs retained their length and NA
placement; the regression matrix found a maximum absolute zenith difference
of zero.

Raw data: [`liljegren-coordinate-cardinality-2.4.0.csv`](liljegren-coordinate-cardinality-2.4.0.csv).
