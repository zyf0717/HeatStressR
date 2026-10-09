# Validation and diagnostics

Numeric scalars expand to the common observation length. Other incompatible
lengths and wrong types raise errors. Missing observations propagate silently.
Physically invalid rows return NA with one summary warning. Observations
outside a documented applicability domain are calculated where possible,
flagged, and summarized in a warning. An unknown validity boundary is recorded
as unknown. Numerical failures are distinct from invalid input.

Single-index functions return numeric vectors. With `diagnostics = TRUE`,
they return `list(values, components, diagnostics)`. The diagnostics contain
aligned row statuses, optional solver details and scientific metadata. Bulk
calculations return a data frame or the corresponding diagnostic list.

Below freezing, published methods differ in their humidity reference phase.
Use the convention reported by `heat_methods()` and do not assume that
water-relative and ice-relative RH are interchangeable.
