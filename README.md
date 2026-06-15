# Heap Primitives

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)
[![CI](https://github.com/swift-primitives/swift-heap-primitives/actions/workflows/ci.yml/badge.svg)](https://github.com/swift-primitives/swift-heap-primitives/actions/workflows/ci.yml)

`Heap<Element>` — a binary heap (priority queue) with configurable ordering. Insertion and removal of the priority element are O(log n); reading the priority element is O(1). The ordering passed at construction decides whether the minimum or the maximum element has highest priority, so one type serves as both a min-heap and a max-heap.

`Heap` carries any element that defines a comparison, including move-only (`~Copyable`) ones — elements are stored and surfaced by ownership transfer, never an implicit copy. It is the canonical heap; the binary structure is an implementation detail behind the priority-queue surface.

---

## Key Features

- **Min or max from one type** — `Heap(order: .ascending)` is a min-heap, `.descending` a max-heap.
- **O(log n) push / pop, O(1) peek** — standard binary-heap performance.
- **Move-only elements** — `~Copyable` elements supported; push/pop transfer ownership.
- **Comparison-driven** — orders any element that conforms to the comparison capability.

---

## Quick Start

```swift
import Heap_Primitives

var minHeap = Heap<Int>(order: .ascending)   // min-heap
minHeap.push(42)
minHeap.push(7)
let top = minHeap.peek            // Optional(7) — O(1), the priority element
let removed = try minHeap.pop()   // 7 — O(log n)
```

---

## Installation

Add the dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/swift-primitives/swift-heap-primitives.git", branch: "main")
]
```

Add the product to your target:

```swift
.target(
    name: "App",
    dependencies: [
        .product(name: "Heap Primitives", package: "swift-heap-primitives")
    ]
)
```

The package is pre-1.0 — depend on `branch: "main"` until `0.1.0` is tagged. Requires Swift 6.3 and macOS 26 / iOS 26 / tvOS 26 / watchOS 26 / visionOS 26 (or the corresponding Linux / Windows toolchain).

---

## Architecture

| Product | Contents | When to import |
|---------|----------|----------------|
| `Heap Primitives` | Umbrella — `Heap` and its conformances | Most consumers |
| `Heap Primitive` | `Heap<Element>` — the binary heap / priority queue | Naming the type directly |

---

## Platform Support

| Platform         | CI  | Status       |
|------------------|-----|--------------|
| macOS 26         | Yes | Full support |
| Linux            | Yes | Full support |
| Windows          | Yes | Full support |
| iOS/tvOS/watchOS | —   | Supported    |
| Swift Embedded   | —   | Pending (nightly-toolchain follow-up) |

---

## Related Packages

- [`swift-comparison-primitives`](https://github.com/swift-primitives/swift-comparison-primitives) — the comparison capability `Heap` orders its elements by.
- [`swift-array-primitives`](https://github.com/swift-primitives/swift-array-primitives) — the sequential-container sibling.
- [`swift-graph-primitives`](https://github.com/swift-primitives/swift-graph-primitives) — a consumer: priority-first traversals use a heap.

---

## Community

<!-- BEGIN: discussion -->
<!-- END: discussion -->

## License

Apache 2.0. See [LICENSE.md](LICENSE.md).
