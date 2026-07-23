# Three-way Liljegren benchmark

Recorded 2026-07-23 on macOS arm64 (`aarch64-apple-darwin25.4.0`) with R
4.6.1. This benchmark holds latitude/longitude fixed while using unique
timestamps, so every `(timestamp, lon, lat)` triplet is distinct. It compares
complete `wbgt.Liljegren()` calls at three implementations:

- pre-fork commit `f77a263ba6820a79b7092518ff4376c787ac45b2`;
- HeatStressR 2.1.6 scalar engine; and
- HeatStressR 2.1.6 batch engine.

Each value is the median of three repetitions over the same deterministic
weather series. Radiation is derived from solar elevation before timing.

| Rows | Pre-fork | Current scalar | Current batch | Batch / scalar speedup |
| ---: | ---: | ---: | ---: | ---: |
| 100 | 0.064 s | 0.113 s | 0.087 s | 1.30x |
| 1,000 | 0.438 s | 0.274 s | 0.020 s | 13.70x |
| 10,000 | 4.411 s | 2.933 s | 0.114 s | 25.73x |
| 100,000 | 44.826 s | 27.897 s | 1.052 s | 26.52x |

Every measured output had finite Tg, Tnwb, and WBGT values. The pre-fork arm
uses the historical fixed-coordinate API; it is included only for performance
comparison and is not a numerical-equivalence claim.

Raw data: [`liljegren-three-way.csv`](liljegren-three-way.csv).
