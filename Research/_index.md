# Research Index -- swift-heap-primitives

<!--
---
version: 1.0.0
last_updated: 2026-02-16
---
-->

## Documents

| Document | Version | Status | Updated | Summary |
|----------|---------|--------|---------|---------|
| [heap-discipline-boundary-analysis.md](heap-discipline-boundary-analysis.md) | 1.0.0 | RECOMMENDATION | 2026-02-14 | Verifies that heap-primitives contains only heap-discipline semantics and no buffer-layer concerns have leaked upward. Classifies every public API member as heap, delegation, or contested. |
| [heap-operations-audit.md](heap-operations-audit.md) | 1.0.0 | RECOMMENDATION | 2026-02-16 | Inventories all public operations across every variant (Heap, Fixed, Static, Small, MinMax) and compares against canonical Heap/Priority Queue ADT operations. Identifies gaps in variant completeness and intentionally absent operations. |
