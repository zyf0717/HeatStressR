# Liljegren residual-tolerance sensitivity

Deterministic 100,000-row batch workload, 2026-07-21. All runs used
`root_tolerance = 1e-6`.

| residual tolerance | complete WBGT | rejected | Tg failures | Tnwb failures | unbracketed | non-finite | residual-invalid | max accepted residual | max baseline difference |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0.0001 | 100,000 | 0 | 0 | 0 | 0 | 0 | 0 | 7.739878e-06 | 0 |
| 0.0003 | 100,000 | 0 | 0 | 0 | 0 | 0 | 0 | 7.739878e-06 | 0 |
| 0.001 | 100,000 | 0 | 0 | 0 | 0 | 0 | 0 | 7.739878e-06 | 0 |
| 0.003 | 100,000 | 0 | 0 | 0 | 0 | 0 | 0 | 7.739878e-06 | 0 |
| 0.01 | 100,000 | 0 | 0 | 0 | 0 | 0 | 0 | 7.739878e-06 | 0 |

Internally consistent solar forcing recovers all previously unresolved rows.
No candidate was rejected solely by residual validation. The default residual
tolerance remains `1e-4`.
