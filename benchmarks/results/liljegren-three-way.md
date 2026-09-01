# Three-way Liljegren benchmark

Recorded 2026-09-02 on Linux x86-64 (`x86_64-pc-linux-gnu`) with R 4.6.1 on
an Intel Core i9-13900HK. This benchmark holds latitude/longitude fixed while
using unique timestamps, so every `(timestamp, lon, lat)` triplet is distinct.
It compares complete `wbgt.Liljegren()` calls at three implementations:

- pre-fork commit `f77a263ba6820a79b7092518ff4376c787ac45b2`;
- HeatStressR 2.4.0 scalar engine; and
- HeatStressR 2.4.0 batch engine.

Each value is the median of three repetitions over the same deterministic
weather series. Radiation is derived from solar elevation before timing.

| Rows | Pre-fork | 2.4.0 scalar | 2.4.0 batch | Batch / pre-fork | Batch / scalar |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 100 | 0.074 s | 0.125 s | 0.095 s | 0.78x | 1.32x |
| 1,000 | 0.488 s | 0.300 s | 0.013 s | 37.54x | 23.08x |
| 10,000 | 4.945 s | 3.063 s | 0.090 s | 54.94x | 34.03x |
| 100,000 | 49.423 s | 31.329 s | 0.951 s | 51.97x | 32.94x |

Every measured output had finite Tg, Tnwb, and WBGT values. The pre-fork arm
uses the historical fixed-coordinate API; it is included only for performance
comparison and is not a numerical-equivalence claim. At 100 rows, fixed process
startup and package overhead dominate the measured batch call.

Raw data: [`liljegren-three-way.csv`](liljegren-three-way.csv).
