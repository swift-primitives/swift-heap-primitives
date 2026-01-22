# Heap Primitives Insights

<!--
---
title: Heap Primitives Insights
version: 1.0.0
last_updated: 2026-01-22
applies_to: [swift-heap-primitives]
normative: false
---
-->

@Metadata {
    @TitleHeading("Heap Primitives")
}

Design decisions, implementation patterns, and lessons learned specific to this package.

## Overview

This document captures insights that emerged during development of swift-heap-primitives. These are not API requirements—they are recorded decisions and patterns that inform future work on this package.

**Document type**: Non-normative (recorded decisions, not requirements).

**Consolidation source**: Reflection entries tagged with `[Package: swift-heap-primitives]`.

---

## The Single-File Workaround for Module Emission Bugs

**Date**: 2026-01-20

**Context**: Discovering that a compiler bug affecting ~Copyable Sequence conformance can be bypassed by consolidating all source files into one.

After documenting and filing Swift issue #86669—a compiler bug that breaks Sequence conformance for types with compound generic constraints (`Element: ~Copyable & Protocol`)—the investigation turned to workarounds. The original attempt (moving `borrowing Element` methods to the main file) worked for the minimal reproduction but failed for the full Heap implementation.

The breakthrough came from asking: "What if we put everything in one file?"

A 4000-line consolidated file compiles successfully with Sequence conformance enabled, while the same code split across 12 files fails during module emission.

### Why File Boundaries Matter

The bug manifests specifically in the `-emit-module` phase. Module emission processes files in a particular order and builds cross-file relationships. The bug appears to be a constraint propagation failure that occurs when:

1. A nested type has `UnsafeMutablePointer<Element>` where `Element: ~Copyable & Protocol`
2. A conditional `Sequence` conformance exists (`where Element: Copyable`)
3. A separate file contains methods with `(borrowing Element)` closure parameters

When all code is in one file, the constraint solver sees the complete picture in a single pass. When split across files, the module emission phase loses track of the `~Copyable` suppression somewhere in the cross-file linking.

### The Trade-Off Accepted

Consolidating swift-heap-primitives into a single 4084-line file violates [API-IMPL-005] (one type per file). This is explicitly documented as temporary:

```swift
// WORKAROUND: This Sequence conformance only compiles because all source code
// is consolidated into a single file. When the compiler bug is fixed, this
// package can be restructured into multiple files per [API-IMPL-005].
```

The violation meets [PATTERN-016] Conscious Technical Debt criteria:
- **Intentional**: Chosen to enable Sequence conformance
- **Documented**: Comments explain why and reference the tracking issue
- **Bounded**: One package, clear scope
- **Reversible**: Can split when bug is fixed

Users get `for-in` loops, `map`, `filter`, and all standard Sequence operations. The cost is internal organization that maintainers must navigate carefully.

### Investigation Pattern

The path to this workaround followed [EXP-004a] methodology:

1. **Isolate**: Created minimal reproduction, confirmed the bug
2. **Document**: Filed Swift issue #86669 with exact trigger conditions
3. **Workaround attempt 1**: Move borrowing methods to main file → FAILED for real codebase
4. **Workaround attempt 2**: Single-file consolidation → SUCCEEDED

The key insight: patterns that work in minimal reproductions don't always scale. When a workaround works in isolation but fails in context, the context itself is a factor.

**Applies to**: All source files in swift-heap-primitives; the single-file consolidation in `Heap Primitives/Heap.swift`.

---

## The Accessor Pattern Boundary

**Date**: 2026-01-20

**Context**: Attempting to unify Heap API by replacing compound methods (`takeMin()`, `popMin()`) with accessor patterns (`heap.take.min`, `heap.pop.min()`) per [API-NAME-002].

The nested accessor pattern requires an accessor struct that holds a reference to the container:

```swift
public struct Take {
    var heap: Heap<Element>.Bounded  // Must hold the container
}
```

For a `~Copyable` container, this is impossible. The accessor struct needs to store the container, but storing a `~Copyable` value requires the accessor itself to be `~Copyable`. A `~Copyable` accessor defeats the purpose—accessors need to be freely passable as intermediate values.

### Why Class Storage Doesn't Help

`Heap.Bounded` uses class-based storage (`ManagedBuffer`), which initially suggested the accessor pattern might work. The reasoning: "The Storage class is a reference type, so the Bounded struct is lightweight and should be copyable."

This reasoning is wrong. The Bounded struct is declared `~Copyable`:

```swift
public struct Bounded: ~Copyable { ... }
```

Even with class-based storage, the struct itself is `~Copyable` to support `~Copyable` elements. The struct becomes `Copyable` only when `Element: Copyable` via conditional conformance. For `~Copyable` elements, the container is `~Copyable`, and the accessor pattern fails.

### The Heap Type Family API Patterns

| Variant | Storage | ~Copyable? | Accessor Pattern? |
|---------|---------|------------|-------------------|
| `Heap` (base) | Class-based (CoW) | Conditional | Yes |
| `Heap.Bounded` | Class-based | Conditional | No (struct is ~Copyable) |
| `Heap.Inline` | Inline | Always | No |
| `Heap.Small` | Hybrid | Always | No |

The divergence between base `Heap` using `heap.take.min` and variants using `heap.takeMin()` is intentional, not inconsistency. It reflects the underlying type constraints:

- **Base Heap**: Accessor pattern works because the container is `Copyable` when elements are
- **Variants**: Compound methods required because containers are `~Copyable` by design

### Decision

For `~Copyable` containers, compound methods (`takeMin()`, `popMin()`) remain the correct pattern. This violates [API-NAME-002] (no compound identifiers), but [MEM-COPY-005] provides the exception for `~Copyable` containers requiring direct methods instead of accessor patterns.

**Applies to**: All Heap variant types (Bounded, Inline, Small) API design.

---

## Experiments as Institutional Memory

**Date**: 2026-01-20

**Context**: Creating the `noncopyable-accessor-pattern` experiment package after discovering the accessor pattern limitation.

The accessor pattern limitation was discovered through production code failure, not systematic experimentation. The experiment package was created *after* the conclusion was reached, to preserve the finding.

### Why Create an Experiment for Documented Behavior

[MEM-COPY-005] already documents this limitation. The experiment adds:

1. **Reproducible proof**: Anyone can verify the limitation by uncommenting failing code
2. **Future reference**: When Swift's ownership model evolves, re-run to check
3. **Onboarding documentation**: New contributors understand why compound methods exist
4. **Issue filing support**: Ready-made reproduction for Swift issues

### Experiment Structure

```
Experiments/noncopyable-accessor-pattern/
├── Package.swift
└── Sources/
    ├── main.swift              # Working code (V1, V2, V3 workarounds)
    └── error-demo.swift.txt    # Failing code with captured compiler output
```

The `.swift.txt` extension preserves failing code without breaking the build. Rename to `.swift` to reproduce the error on demand.

### Variant Table

| Variant | Configuration | Result |
|---------|---------------|--------|
| V1 | Copyable container + accessor | PASS |
| V2 | ~Copyable container + accessor | FAIL |
| V3 | Conditional Copyable + accessor in ~Copyable context | FAIL |

**Applies to**: `Experiments/noncopyable-accessor-pattern/` directory.

---

## Topics

### Related Documents

- <doc:Heap>
