# HeatStressR 2.1.6 internal-worker benchmark

Recorded 2026-07-23 on macOS arm64 (`aarch64-apple-darwin25.4.0`) with R
4.6.1. Every run uses the retained worker benchmark's deterministic
1,000,000-row workload and varies only the requested internal worker count.

The workload repeats 48 coordinate pairs but assigns every row a distinct
hourly UTC timestamp. It therefore has 1,000,000 unique `(timestamp, lon,
lat)` triplets while retaining repeated latitude-longitude pairs.

| Workers | Rows | Runtime | Speedup vs. 1 | Peak aggregate RSS | Rows/s |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 1,000,000 | 10.941 s | 1.00x | 1.80 GiB | 91,399 |
| 2 | 1,000,000 | 5.933 s | 1.84x | 2.54 GiB | 168,549 |
| 3 | 1,000,000 | 4.189 s | 2.61x | 2.56 GiB | 238,721 |
| 4 | 1,000,000 | 3.400 s | 3.22x | 2.37 GiB | 294,118 |
| 5 | 1,000,000 | 2.857 s | 3.83x | 2.80 GiB | 350,018 |
| 6 | 1,000,000 | 2.514 s | 4.35x | 2.93 GiB | 397,773 |

Runtime begins after deterministic workload construction and uses
`diagnostics = FALSE`. Peak aggregate RSS is the sum of the parent R process
and every PSOCK worker, sampled every 50 ms for the timed call. Summed RSS
counts shared resident pages in more than one process, so it is a conservative
memory-pressure measure rather than deduplicated physical memory.

Raw data: [`liljegren-parallel-2.1.6-1000000-unique-triplets.csv`](liljegren-parallel-2.1.6-1000000-unique-triplets.csv).
