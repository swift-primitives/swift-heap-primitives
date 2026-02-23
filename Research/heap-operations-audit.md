# Heap Operations Audit

<!--
---
version: 1.0.0
last_updated: 2026-02-16
status: RECOMMENDATION
tier: 1
---
-->

## Context

Proactive audit of swift-heap-primitives per [RES-012] Discovery.
**Scope**: Package-specific (swift-heap-primitives).

## Question

Does swift-heap-primitives provide the canonical operations expected of the Heap/Priority Queue ADT?

---

## Canonical Operations (ADT Reference)

### Binary Heap (Single-Ended)

| Operation | Expected Complexity | Description |
|-----------|-------------------|-------------|
| insert(x) | O(log n) | Add element, maintain heap property |
| peek_min/peek_max | O(1) | View root element |
| extract_min/extract_max | O(log n) | Remove and return root |
| decrease_key/increase_key | O(log n) | Update priority (with handle) |
| heapify / build | O(n) | Build heap from array |
| merge | O(n) | Merge two heaps (binary) |
| count/size | O(1) | Number of elements |
| isEmpty | O(1) | Empty check |

### MinMax Heap (Double-Ended)

| Operation | Expected Complexity | Description |
|-----------|-------------------|-------------|
| peek_min | O(1) | View minimum |
| peek_max | O(1) | View maximum |
| extract_min | O(log n) | Remove minimum |
| extract_max | O(log n) | Remove maximum |
| insert | O(log n) | Add element, maintain min-max property |
| heapify / build | O(n) | Build min-max heap from array |
| count/size | O(1) | Number of elements |
| isEmpty | O(1) | Empty check |

---

## Current Operations Inventory

### Heap (Dynamic, Single-Ended Binary Heap)

`Heap<Element: ~Copyable & Comparison.Protocol>: ~Copyable`

Configurable ordering via `Heap.Order` (`.ascending` = min-heap, `.descending` = max-heap).

#### Type Declarations and Stored Properties

| Declaration | Visibility | File |
|------------|-----------|------|
| `struct Heap<Element: ~Copyable & Comparison.Protocol>: ~Copyable` | public | `Heap.swift:62` |
| `enum Order: Sendable, Hashable { case ascending, descending }` | public | `Heap.swift:67` |
| `enum Error: Swift.Error, Sendable, Equatable { case empty }` | public | `Heap.swift:77` |
| `let order: Order` | public | `Heap.swift:85` |
| `var _buffer: Buffer<Element>.Linear` | package | `Heap.swift:88` |
| `enum Push.Outcome: ~Copyable { case inserted, case overflow(Element) }` | public | `Heap.swift:143-151` |
| `typealias Binary = Heap` | public | `Heap.swift:247` |
| `typealias Ordering = Comparison.Protocol` | public | `Heap.swift:239` |
| `typealias Index = Index_Primitives.Index<Element>` | public | `Heap.Index.swift:36` |
| `typealias Property<Tag> = Property_Primitives.Property<Tag, Heap>` | public | `Heap ~Copyable.swift:28` |
| `enum Remove` | public | `Heap ~Copyable.swift:19` |

#### Initializers

| Signature | Complexity | Constraint | File |
|-----------|-----------|-----------|------|
| `init(order: Order = .ascending)` | O(1) | `~Copyable` | `Heap.swift:96` |
| `init(_ elements: some Sequence<Element>, order: Order = .ascending)` | O(n) | `Copyable` | `Heap Copyable.swift:26` |
| `init(arrayLiteral elements: Element...)` | O(n) | `Copyable` | `Heap Copyable.swift:196` |

#### Properties (Public)

| Signature | Complexity | Constraint | File |
|-----------|-----------|-----------|------|
| `var count: Heap.Index.Count` | O(1) | `~Copyable` | `Heap ~Copyable.swift:36` |
| `var isEmpty: Bool` | O(1) | `~Copyable` | `Heap ~Copyable.swift:40` |
| `var peek: Element?` | O(1) | `Copyable` | `Heap Copyable.swift:68` |
| `var take: Element?` (mutating get) | O(log n) | `Copyable` | `Heap Copyable.swift:151` |
| `var root: Heap.Index?` | O(1) | `~Copyable` | `Heap.Navigate.swift:123` |
| `var navigate: Navigate` | O(1) | `~Copyable` | `Heap.Navigate.swift:137` |
| `var unordered: Buffer<Element>.Linear` | O(n) | `Copyable` | `Heap Copyable.swift:88` |
| `var remove: Remove.View` (mutating) | O(1) | `~Copyable` | `Heap ~Copyable.swift:207` |
| `var drain: Property<Sequence.Drain>.View` (mutating) | O(1) | `Copyable` | `Heap Copyable.swift (Binary):77` |
| `var underestimatedCount: Int` | O(1) | `Copyable` | `Heap Copyable.swift (Binary):28` |

#### Mutating Methods (Public)

| Signature | Complexity | Constraint | File |
|-----------|-----------|-----------|------|
| `func push(_ element: consuming Element)` | O(log n) | `~Copyable` | `Heap ~Copyable.swift:190` |
| `func push(_ element: Element)` (CoW) | O(log n) | `Copyable` | `Heap Copyable.swift:51` |
| `func pop() throws(Heap.Error) -> Element` | O(log n) | `Copyable` | `Heap Copyable.swift:126` |

#### Borrowing Access (Public)

| Signature | Complexity | Constraint | File |
|-----------|-----------|-----------|------|
| `func withPriority<R>(_ body: (borrowing Element) -> R) -> R?` | O(1) | `~Copyable` | `Heap ~Copyable.swift:247` |
| `func forEach(_ body: (borrowing Element) -> Void)` | O(n) | `~Copyable` | `Heap ~Copyable.swift:264` |

#### Remove Accessor Operations

| Signature | Complexity | Constraint | File |
|-----------|-----------|-----------|------|
| `remove.all(keepingCapacity: Bool = false)` | O(n) | `~Copyable` | `Heap ~Copyable.swift:230` |

#### Protocol Conformances

| Protocol | Constraint | File |
|----------|-----------|------|
| `Copyable` | `where Element: Copyable` | `Heap.swift:253` |
| `@unchecked Sendable` | `where Element: Sendable` | `Heap.swift:266` |
| `Equatable` | `where Element: Equatable & Copyable` | `Heap Copyable.swift:161` |
| `Hashable` | `where Element: Hashable & Copyable` | `Heap Copyable.swift:178` |
| `ExpressibleByArrayLiteral` | `where Element: Copyable` | `Heap Copyable.swift:194` |
| `CustomStringConvertible` | unconditional (non-Embedded) | `Heap Copyable.swift:204` |
| `Swift.Sequence` | `where Element: Copyable` | `Heap Copyable.swift:213` |
| `Sequence.Protocol` | `where Element: Copyable & Comparison.Protocol` | `Heap Copyable.swift (Binary):20` |
| `Sequence.Clearable` | `where Element: Copyable & Comparison.Protocol` | `Heap Copyable.swift (Binary):33` |
| `Sequence.Drain.Protocol` | `where Element: Copyable & Comparison.Protocol` | `Heap Copyable.swift (Binary):45` |

---

### Heap.Min (Stub)

`Heap<Element>.Min: ~Copyable`

**Status**: Not implemented. `init()` calls `fatalError`.

| Declaration | File |
|------------|------|
| `struct Min: ~Copyable` | `Heap.Min.swift:25` |
| `init()` -- fatalError | `Heap.Min.swift:30` |
| `Copyable where Element: Copyable` | `Heap.Min.swift:38` |
| `@unchecked Sendable where Element: Sendable` | `Heap.Min.swift:42` |

---

### Heap.Max (Stub)

`Heap<Element>.Max: ~Copyable`

**Status**: Not implemented. `init()` calls `fatalError`.

| Declaration | File |
|------------|------|
| `struct Max: ~Copyable` | `Heap.Max.swift:25` |
| `init()` -- fatalError | `Heap.Max.swift:30` |
| `Copyable where Element: Copyable` | `Heap.Max.swift:38` |
| `@unchecked Sendable where Element: Sendable` | `Heap.Max.swift:42` |

---

### Heap.Fixed (Fixed-Capacity Single-Ended)

`Heap<Element>.Fixed: ~Copyable`

Uses `Buffer<Element>.Linear.Bounded`. Returns `Heap.Push.Outcome` on push.

#### Type Declarations

| Declaration | Visibility | File |
|------------|-----------|------|
| `struct Fixed: ~Copyable` | public | `Heap.swift:103` |
| `enum Error: Swift.Error { case invalidCapacity, case empty }` | public | `Heap.swift:105` |
| `let order: Order` | public | `Heap.swift:116` |
| `var _buffer: Buffer<Element>.Linear.Bounded` | package | `Heap.swift:113` |
| `typealias Property<Tag>` | public | `Heap.Fixed ~Copyable.swift:29` |
| `enum Remove` | public | `Heap.Fixed ~Copyable.swift:20` |

#### Initializers

| Signature | Complexity | Constraint | File |
|-----------|-----------|-----------|------|
| `init(capacity: Int, order: Order = .ascending) throws(Fixed.Error)` | O(1) | `~Copyable` | `Heap.swift:125` |
| `init(_ elements: some Sequence<Element>, capacity: Int, order: Order = .ascending) throws(Fixed.Error)` | O(n) | `Copyable` | `Heap.Fixed Copyable.swift:398` |

#### Properties (Public)

| Signature | Complexity | Constraint | File |
|-----------|-----------|-----------|------|
| `var count: Heap.Index.Count` | O(1) | `~Copyable` | `Heap.Fixed ~Copyable.swift:37` |
| `var isEmpty: Bool` | O(1) | `~Copyable` | `Heap.Fixed ~Copyable.swift:41` |
| `var isFull: Bool` | O(1) | `~Copyable` | `Heap.Fixed ~Copyable.swift:45` |
| `var capacity: Heap.Index.Count` | O(1) | `~Copyable` | `Heap.Fixed ~Copyable.swift:49` |
| `var peek: Element?` | O(1) | `Copyable` | `Heap.Fixed Copyable.swift:372` |
| `var take: Element?` (mutating get) | O(log n) | `~Copyable` | `Heap.Fixed ~Copyable.swift:210` |
| `var take: Element?` (mutating get, CoW) | O(log n) | `Copyable` | `Heap.Fixed Copyable.swift:329` |
| `var root: Heap.Index?` | O(1) | `~Copyable` | `Heap.Fixed ~Copyable.swift:494` |
| `var navigate: Heap.Navigate` | O(1) | `~Copyable` | `Heap.Fixed ~Copyable.swift:500` |
| `var remove: Remove.View` (mutating) | O(1) | `~Copyable` | `Heap.Fixed ~Copyable.swift:241` |
| `var drain: Property<Sequence.Drain>.View` (mutating) | O(1) | `Copyable` | `Heap.Fixed Copyable.swift:101` |
| `var span: Span<Element>` | O(1) | `~Copyable` | `Heap.Fixed ~Copyable.swift:454` |
| `var mutableSpan: MutableSpan<Element>` | O(1) | `~Copyable` | `Heap.Fixed ~Copyable.swift:465` |
| `var mutableSpan: MutableSpan<Element>` (CoW) | O(1) | `Copyable` | `Heap.Fixed Copyable.swift:478` |

#### Mutating Methods (Public)

| Signature | Complexity | Constraint | File |
|-----------|-----------|-----------|------|
| `func push(_ element: consuming Element) -> Heap.Push.Outcome` | O(log n) | `~Copyable` | `Heap.Fixed ~Copyable.swift:197` |
| `func push(_ element: Element) -> Heap.Push.Outcome` (CoW) | O(log n) | `Copyable` | `Heap.Fixed Copyable.swift:318` |
| `func pop() throws(Fixed.Error) -> Element` | O(log n) | `~Copyable` | `Heap.Fixed ~Copyable.swift:222` |
| `func pop() throws(Fixed.Error) -> Element` (CoW) | O(log n) | `Copyable` | `Heap.Fixed Copyable.swift:338` |
| `func truncate(to newCount: Heap.Index.Count)` | O(k) | `~Copyable` | `Heap.Fixed ~Copyable.swift:427` |
| `func truncate(to newCount: Heap.Index.Count)` (CoW) | O(k) | `Copyable` | `Heap.Fixed Copyable.swift:438` |

#### Borrowing Access (Public)

| Signature | Complexity | Constraint | File |
|-----------|-----------|-----------|------|
| `func withPriority<R>(_ body: (borrowing Element) -> R) -> R?` | O(1) | `~Copyable` | `Heap.Fixed ~Copyable.swift:279` |
| `func forEach(_ body: (borrowing Element) -> Void)` | O(n) | `~Copyable` | `Heap.Fixed ~Copyable.swift:296` |
| `func element(at index: Heap.Index) -> Element?` | O(1) | `Copyable` | `Heap.Fixed Copyable.swift:379` |

#### Remove Accessor Operations

| Signature | Complexity | Constraint | File |
|-----------|-----------|-----------|------|
| `remove.all()` | O(n) | `~Copyable` | `Heap.Fixed ~Copyable.swift:263` |
| `remove.all()` (CoW) | O(n) | `Copyable` | `Heap.Fixed Copyable.swift:358` |

#### Protocol Conformances

| Protocol | Constraint | File |
|----------|-----------|------|
| `Copyable` | `where Element: Copyable` | `Heap.swift:256` |
| `@unchecked Sendable` | `where Element: Sendable` | `Heap.swift:267` |
| `Swift.Sequence` | `where Element: Copyable` | `Heap.Fixed Copyable.swift:120` |
| `Sequence.Protocol` | `where Element: Copyable & Comparison.Protocol` | `Heap.Fixed Copyable.swift:48` |
| `Sequence.Clearable` | `where Element: Copyable & Comparison.Protocol` | `Heap.Fixed Copyable.swift:67` |
| `Sequence.Drain.Protocol` | `where Element: Copyable & Comparison.Protocol` | `Heap.Fixed Copyable.swift:80` |

---

### Heap.Static (Compile-Time Capacity, Inline Storage)

`Heap<Element>.Static<let capacity: Int>: ~Copyable`

Uses `Buffer<Element>.Linear.Inline<capacity>`. Unconditionally `~Copyable` (deinit requirement).

#### Type Declarations

| Declaration | Visibility | File |
|------------|-----------|------|
| `struct Static<let capacity: Int>: ~Copyable` | public | `Heap.swift:160` |
| `enum Error: Swift.Error { case empty }` | public | `Heap.swift:162` |
| `let order: Order` | public | `Heap.swift:170` |
| `var _buffer: Buffer<Element>.Linear.Inline<capacity>` | package | `Heap.swift:168` |
| `typealias Property<Tag>` | public | `Heap.Static ~Copyable.swift:28` |
| `enum Remove` | public | `Heap.Static ~Copyable.swift:19` |

#### Initializers

| Signature | Complexity | Constraint | File |
|-----------|-----------|-----------|------|
| `init(order: Order = .ascending)` | O(1) | `~Copyable` | `Heap.swift:177` |

#### Properties (Public)

| Signature | Complexity | Constraint | File |
|-----------|-----------|-----------|------|
| `var count: Heap.Index.Count` | O(1) | `~Copyable` | `Heap.Static ~Copyable.swift:36` |
| `var isEmpty: Bool` | O(1) | `~Copyable` | `Heap.Static ~Copyable.swift:40` |
| `var isFull: Bool` | O(1) | `~Copyable` | `Heap.Static ~Copyable.swift:44` |
| `var peek: Element?` (mutating get) | O(1) | `Copyable` | `Heap.Static Copyable.swift:202` |
| `var take: Element?` (mutating get) | O(log n) | `~Copyable` | `Heap.Static ~Copyable.swift:207` |
| `var root: Heap.Index?` | O(1) | `~Copyable` | `Heap.Static ~Copyable.swift:320` |
| `var navigate: Heap.Navigate` | O(1) | `~Copyable` | `Heap.Static ~Copyable.swift:326` |
| `var remove: Remove.View` (mutating) | O(1) | `~Copyable` | `Heap.Static ~Copyable.swift:238` |

#### Mutating Methods (Public)

| Signature | Complexity | Constraint | File |
|-----------|-----------|-----------|------|
| `func push(_ element: consuming Element) -> Heap.Push.Outcome` | O(log n) | `~Copyable` | `Heap.Static ~Copyable.swift:194` |
| `func pop() throws(Static<capacity>.Error) -> Element` | O(log n) | `~Copyable` | `Heap.Static ~Copyable.swift:219` |
| `func truncate(to newCount: Heap.Index.Count)` | O(k) | `~Copyable` | `Heap.Static ~Copyable.swift:307` |

#### Borrowing Access (Public)

| Signature | Complexity | Constraint | File |
|-----------|-----------|-----------|------|
| `func withPriority<R>(_ body: (borrowing Element) -> R) -> R?` | O(1) | `~Copyable` | `Heap.Static ~Copyable.swift:272` |
| `func forEach(_ body: (borrowing Element) -> Void)` | O(n) | `~Copyable` | `Heap.Static ~Copyable.swift:289` |

#### Remove Accessor Operations

| Signature | Complexity | Constraint | File |
|-----------|-----------|-----------|------|
| `remove.all()` | O(n) | `~Copyable` | `Heap.Static ~Copyable.swift:258` |

#### Property View Accessors (Copyable)

| Accessor | File |
|----------|------|
| `var drain: Drain.View` | `Heap.Static Copyable.swift:146` |
| `var forEach: ForEach.View` | `Heap.Static Copyable.swift:152` |
| `var satisfies: Satisfies.View` | `Heap.Static Copyable.swift:158` |
| `var first: First.View` | `Heap.Static Copyable.swift:164` |
| `var reduce: Reduce.View` | `Heap.Static Copyable.swift:170` |
| `var contains: Contains.View` | `Heap.Static Copyable.swift:176` |
| `var drop: Drop.View` | `Heap.Static Copyable.swift:182` |
| `var prefix: Prefix.View` | `Heap.Static Copyable.swift:188` |

#### Protocol Conformances

| Protocol | Constraint | File |
|----------|-----------|------|
| `@unchecked Sendable` | `where Element: Sendable` | `Heap.swift:269` |
| `Sequence.Protocol` | `where Element: Copyable & Comparison.Protocol` | `Heap.Static Copyable.swift:54` |
| `Sequence.Clearable` | `where Element: Copyable & Comparison.Protocol` | `Heap.Static Copyable.swift:82` |
| `Sequence.Drain.Protocol` | `where Element: Copyable & Comparison.Protocol` | `Heap.Static Copyable.swift:94` |

**Note**: `Heap.Static` is unconditionally `~Copyable` and therefore cannot conform to `Swift.Sequence`. Iteration uses `forEach` or `makeIterator()` which returns a snapshot-based iterator.

---

### Heap.Small (Small-Buffer Optimization)

`Heap<Element>.Small<let inlineCapacity: Int>: ~Copyable`

Uses `Buffer<Element>.Linear.Small<inlineCapacity>`. Unconditionally `~Copyable` (deinit requirement).

#### Type Declarations

| Declaration | Visibility | File |
|------------|-----------|------|
| `struct Small<let inlineCapacity: Int>: ~Copyable` | public | `Heap.swift:190` |
| `enum Error: Swift.Error { case empty }` | public | `Heap.swift:193` |
| `let order: Order` | public | `Heap.swift:200` |
| `var _buffer: Buffer<Element>.Linear.Small<inlineCapacity>` | package | `Heap.swift:198` |
| `typealias Property<Tag>` | public | `Heap.Small ~Copyable.swift:29` |
| `enum Remove` | public | `Heap.Small ~Copyable.swift:20` |

#### Initializers

| Signature | Complexity | Constraint | File |
|-----------|-----------|-----------|------|
| `init(order: Order = .ascending)` | O(1) | `~Copyable` | `Heap.swift:206` |

#### Properties (Public)

| Signature | Complexity | Constraint | File |
|-----------|-----------|-----------|------|
| `var count: Heap.Index.Count` | O(1) | `~Copyable` | `Heap.Small ~Copyable.swift:75` |
| `var isEmpty: Bool` | O(1) | `~Copyable` | `Heap.Small ~Copyable.swift:79` |
| `var capacity: Index<Element>.Count` | O(1) | `~Copyable` | `Heap.Small ~Copyable.swift:83` |
| `var isSpilled: Bool` | O(1) | `~Copyable` | `Heap.Small ~Copyable.swift:87` |
| `var peek: Element?` (mutating get) | O(1) | `Copyable` | `Heap.Small Copyable.swift:119` |
| `var take: Element?` (mutating get) | O(log n) | `~Copyable` | `Heap.Small ~Copyable.swift:247` |
| `var root: Heap.Index?` | O(1) | `~Copyable` | `Heap.Small ~Copyable.swift:349` |
| `var navigate: Heap.Navigate` | O(1) | `~Copyable` | `Heap.Small ~Copyable.swift:355` |
| `var remove: Remove.View` (mutating) | O(1) | `~Copyable` | `Heap.Small ~Copyable.swift:43` |
| `var span: Span<Element>` | O(1) | `~Copyable` | `Heap.Small ~Copyable.swift:323` |
| `var mutableSpan: MutableSpan<Element>` | O(1) | `~Copyable` | `Heap.Small ~Copyable.swift:334` |

#### Mutating Methods (Public)

| Signature | Complexity | Constraint | File |
|-----------|-----------|-----------|------|
| `func push(_ element: consuming Element)` | O(log n) amortized | `~Copyable` | `Heap.Small ~Copyable.swift:238` |
| `func pop() throws(Small<inlineCapacity>.Error) -> Element` | O(log n) | `~Copyable` | `Heap.Small ~Copyable.swift:259` |
| `func truncate(to newCount: Heap.Index.Count)` | O(k) | `~Copyable` | `Heap.Small ~Copyable.swift:308` |

#### Borrowing Access (Public)

| Signature | Complexity | Constraint | File |
|-----------|-----------|-----------|------|
| `func withPriority<R>(_ body: (borrowing Element) -> R) -> R?` | O(1) | `~Copyable` | `Heap.Small ~Copyable.swift:276` |
| `func forEach(_ body: (borrowing Element) -> Void)` | O(n) | `~Copyable` | `Heap.Small ~Copyable.swift:293` |

#### Remove Accessor Operations

| Signature | Complexity | Constraint | File |
|-----------|-----------|-----------|------|
| `remove.all()` | O(n) | `~Copyable` | `Heap.Small ~Copyable.swift:65` |

#### Property View Accessors (Copyable)

| Accessor | File |
|----------|------|
| `var drain: Drain.View` | `Heap.Small Copyable.swift:160` |
| `var forEach: ForEach.View` | `Heap.Small Copyable.swift:166` |
| `var satisfies: Satisfies.View` | `Heap.Small Copyable.swift:172` |
| `var first: First.View` | `Heap.Small Copyable.swift:178` |
| `var reduce: Reduce.View` | `Heap.Small Copyable.swift:184` |
| `var contains: Contains.View` | `Heap.Small Copyable.swift:190` |
| `var drop: Drop.View` | `Heap.Small Copyable.swift:196` |
| `var prefix: Prefix.View` | `Heap.Small Copyable.swift:202` |

#### Protocol Conformances

| Protocol | Constraint | File |
|----------|-----------|------|
| `@unchecked Sendable` | `where Element: Sendable` | `Heap.swift:270` |
| `Sequence.Protocol` | `where Element: Copyable & Comparison.Protocol` | `Heap.Small Copyable.swift:54` |
| `Sequence.Clearable` | `where Element: Copyable & Comparison.Protocol` | `Heap.Small Copyable.swift:82` |
| `Sequence.Drain.Protocol` | `where Element: Copyable & Comparison.Protocol` | `Heap.Small Copyable.swift:95` |

**Note**: `Heap.Small` is unconditionally `~Copyable` and therefore cannot conform to `Swift.Sequence`. Same snapshot-iterator approach as `Heap.Static`.

---

### Heap.MinMax (Dynamic, Double-Ended)

`Heap<Element>.MinMax: ~Copyable`

Uses `Buffer<Element>.Linear`. Both min and max accessible in O(1).

#### Type Declarations

| Declaration | Visibility | File |
|------------|-----------|------|
| `struct MinMax: ~Copyable` (declared inside Heap body) | public | `Heap.swift:222` |
| `enum Position: Sendable, Equatable { case min, case max }` | public | `Heap.MinMax.swift:23` |
| `typealias Error = Heap.Error` | public | `Heap.MinMax.swift:45` |
| `var _buffer: Buffer<Element>.Linear` | package | `Heap.swift:224` |
| `typealias Property<Tag>` | public | `Heap.MinMax.swift:62` |
| `enum Min` | public | `Heap.MinMax ~Copyable.swift:17` |
| `enum Max` | public | `Heap.MinMax ~Copyable.swift:23` |
| `enum Remove` | public | `Heap.MinMax ~Copyable.swift:28` |
| `enum Peek` (Copyable only) | public | `Heap.MinMax ~Copyable.swift:34` |

#### Initializers

| Signature | Complexity | Constraint | File |
|-----------|-----------|-----------|------|
| `init()` | O(1) | `~Copyable` | `Heap.swift:228` |
| `init(_ elements: some Sequence<Element>)` | O(n) | `Copyable` | `Heap.MinMax Copyable.swift:79` |
| `init(arrayLiteral elements: Element...)` | O(n) | `Copyable` | `Heap.MinMax Copyable.swift:148` |

#### Properties (Public)

| Signature | Complexity | Constraint | File |
|-----------|-----------|-----------|------|
| `var count: Heap.Index.Count` | O(1) | `~Copyable` | `Heap.MinMax ~Copyable.swift:44` |
| `var isEmpty: Bool` | O(1) | `~Copyable` | `Heap.MinMax ~Copyable.swift:48` |
| `var peek: Peek.Typed` (non-mutating) | O(1) | `Copyable` | `Heap.MinMax Copyable.swift:210` |
| `var min: Min.View` (mutating) | O(1) | `Copyable` | `Heap.MinMax Copyable.swift:265` |
| `var max: Max.View` (mutating) | O(1) | `Copyable` | `Heap.MinMax Copyable.swift:330` |
| `var remove: Remove.View` (mutating) | O(1) | `~Copyable` | `Heap.MinMax.swift:77` |
| `var drain: Property<Sequence.Drain>.View` (mutating) | O(1) | `Copyable` | `Heap.MinMax Copyable.swift:61` |
| `var underestimatedCount: Int` | O(1) | `Copyable` | `Heap.MinMax Copyable.swift:24` |

#### Peek Accessor Operations (Non-mutating, Copyable)

| Signature | Complexity | File |
|-----------|-----------|------|
| `peek.min -> Element?` | O(1) | `Heap.MinMax Copyable.swift:224` |
| `peek.max -> Element?` | O(1) | `Heap.MinMax Copyable.swift:233` |

#### Min Accessor Operations (Mutating, Copyable)

| Signature | Complexity | File |
|-----------|-----------|------|
| `min.peek -> Element?` | O(1) | `Heap.MinMax Copyable.swift:286` |
| `min.pop() throws(Error) -> Element` | O(log n) | `Heap.MinMax Copyable.swift:297` |
| `min.take -> Element?` | O(log n) | `Heap.MinMax Copyable.swift:310` |

#### Max Accessor Operations (Mutating, Copyable)

| Signature | Complexity | File |
|-----------|-----------|------|
| `max.peek -> Element?` | O(1) | `Heap.MinMax Copyable.swift:351` |
| `max.pop() throws(Error) -> Element` | O(log n) | `Heap.MinMax Copyable.swift:374` |
| `max.take -> Element?` | O(log n) | `Heap.MinMax Copyable.swift:387` |

#### Mutating Methods (Public)

| Signature | Complexity | Constraint | File |
|-----------|-----------|-----------|------|
| `func push(_ element: consuming Element)` | O(log n) | `~Copyable` | `Heap.MinMax ~Copyable.swift:329` |
| `func push(_ element: Element)` (CoW) | O(log n) | `Copyable` | `Heap.MinMax Copyable.swift:106` |

#### Borrowing Access (Public)

| Signature | Complexity | Constraint | File |
|-----------|-----------|-----------|------|
| `func withMin<R>(_ body: (borrowing Element) -> R) -> R?` | O(1) | `~Copyable` | `Heap.MinMax ~Copyable.swift:339` |
| `func withMax<R>(_ body: (borrowing Element) -> R) -> R?` | O(1) | `~Copyable` | `Heap.MinMax ~Copyable.swift:346` |
| `func forEach(_ body: (borrowing Element) -> Void)` | O(n) | `~Copyable` | `Heap.MinMax ~Copyable.swift:367` |

#### Remove Accessor Operations

| Signature | Complexity | Constraint | File |
|-----------|-----------|-----------|------|
| `remove.all(keepingCapacity: Bool = false)` | O(n) | `~Copyable` | `Heap.MinMax.swift:100` |

#### Protocol Conformances

| Protocol | Constraint | File |
|----------|-----------|------|
| `Copyable` | `where Element: Copyable` | `Heap.swift:259` |
| `@unchecked Sendable` | `where Element: Sendable` | `Heap.swift:268` |
| `Equatable` | `where Element: Equatable & Copyable` | `Heap.MinMax Copyable.swift:115` |
| `Hashable` | `where Element: Hashable & Copyable` | `Heap.MinMax Copyable.swift:131` |
| `ExpressibleByArrayLiteral` | `where Element: Copyable` | `Heap.MinMax Copyable.swift:146` |
| `CustomStringConvertible` | unconditional (non-Embedded) | `Heap.MinMax Copyable.swift:156` |
| `Swift.Sequence` | `where Element: Copyable` | `Heap.MinMax Copyable.swift:165` |
| `Sequence.Protocol` | `where Element: Copyable & Comparison.Protocol` | `Heap.MinMax Copyable.swift:16` |
| `Sequence.Clearable` | `where Element: Copyable & Comparison.Protocol` | `Heap.MinMax Copyable.swift:29` |
| `Sequence.Drain.Protocol` | `where Element: Copyable & Comparison.Protocol` | `Heap.MinMax Copyable.swift:41` |

---

### Heap.MinMax.Fixed (Stub)

`Heap<Element>.MinMax.Fixed: ~Copyable`

**Status**: Declaration only. Has `init(capacity:)` and stored buffer, but no heap operations implemented.

| Declaration | File |
|------------|------|
| `struct Fixed: ~Copyable` | `Heap.MinMax.Fixed.swift:16` |
| `var _buffer: Buffer<Element>.Linear.Bounded` | `Heap.MinMax.Fixed.swift:18` |
| `init(capacity: Int) throws(Heap.Fixed.Error)` | `Heap.MinMax.Fixed.swift:25` |
| `typealias Error = Heap.Fixed.Error` | `Heap.MinMax.swift:50` |
| `@unchecked Sendable where Element: Sendable` | `Heap.MinMax.swift:37` |

---

### Heap.MinMax.Static (Stub)

`Heap<Element>.MinMax.Static<let capacity: Int>: ~Copyable`

**Status**: Declaration only. Has `init()` and stored buffer, but no heap operations implemented.

| Declaration | File |
|------------|------|
| `struct Static<let capacity: Int>: ~Copyable` | `Heap.MinMax.Static.swift:16` |
| `enum Error: Swift.Error { case empty }` | `Heap.MinMax.Static.swift:18` |
| `var _buffer: Buffer<Element>.Linear.Inline<capacity>` | `Heap.MinMax.Static.swift:24` |
| `init()` | `Heap.MinMax.Static.swift:28` |
| `@unchecked Sendable where Element: Sendable` | `Heap.MinMax.swift:38` |

---

### Heap.MinMax.Small (Stub)

`Heap<Element>.MinMax.Small<let inlineCapacity: Int>: ~Copyable`

**Status**: Declaration only. Has `init()` and stored buffer, but no heap operations implemented.

| Declaration | File |
|------------|------|
| `struct Small<let inlineCapacity: Int>: ~Copyable` | `Heap.MinMax.Small.swift:16` |
| `enum Error: Swift.Error { case empty }` | `Heap.MinMax.Small.swift:18` |
| `var _buffer: Buffer<Element>.Linear.Small<inlineCapacity>` | `Heap.MinMax.Small.swift:24` |
| `init()` | `Heap.MinMax.Small.swift:28` |
| `@unchecked Sendable where Element: Sendable` | `Heap.MinMax.swift:39` |

---

### Heap.Navigate (Index Navigation)

`Heap<Element>.Navigate: Sendable, Hashable`

Shared by all variants via `var navigate: Heap.Navigate`.

| Signature | Visibility | Complexity | File |
|-----------|-----------|-----------|------|
| `struct Navigate: Sendable, Hashable` | public | -- | `Heap.Navigate.swift:35` |
| `enum Child { case left, case right }` | public | -- | `Heap.Navigate.swift:37` |
| `func parent(of index: Heap.Index) -> Heap.Index?` | public | O(1) | `Heap.Navigate.swift:57` |
| `func child(_ child: Child, of index: Heap.Index) -> Heap.Index?` | public | O(1) | `Heap.Navigate.swift:70` |
| `func isValid(_ index: Heap.Index) -> Bool` | public | O(1) | `Heap.Navigate.swift:109` |
| `var lastNonLeaf: Heap.Index?` | package | O(1) | `Heap.Navigate.swift:87` |
| `static var leftChildOfRoot: Heap.Index` | package | O(1) | `Heap.Navigate.swift:94` |
| `static var rightChildOfRoot: Heap.Index` | package | O(1) | `Heap.Navigate.swift:100` |

---

### Heap.Storage / Heap.Storage.Inline

Both files are intentionally empty stubs: "Replaced by Buffer.Linear from swift-buffer-primitives."

---

## Gap Analysis

### Present and Correctly Mapped

| Canonical Operation | swift-heap-primitives API | Variants Covered | Complexity |
|--------------------|--------------------------|-----------------:|-----------|
| **insert(x)** | `push(_ element:)` | Heap, Fixed, Static, Small, MinMax | O(log n) |
| **peek_min / peek_max** | `peek` (single-ended), `peek.min` / `peek.max` (MinMax), `min.peek` / `max.peek` (MinMax) | Heap, Fixed, Static, Small, MinMax | O(1) |
| **extract_min / extract_max** | `pop() throws`, `take` (optional variant) | Heap, Fixed, Static, Small | O(log n) |
| **extract_min** (MinMax) | `min.pop() throws`, `min.take` | MinMax | O(log n) |
| **extract_max** (MinMax) | `max.pop() throws`, `max.take` | MinMax | O(log n) |
| **heapify / build** | `init(_ elements:)` (Sequence init), internal `heapify()` | Heap, Fixed, MinMax | O(n) |
| **count / size** | `var count: Heap.Index.Count` | ALL variants | O(1) |
| **isEmpty** | `var isEmpty: Bool` | ALL variants | O(1) |
| **borrowing peek** (~Copyable) | `withPriority(_:)` (single-ended), `withMin(_:)` / `withMax(_:)` (MinMax) | Heap, Fixed, Static, Small, MinMax | O(1) |
| **remove all** | `remove.all()` / `remove.all(keepingCapacity:)` | Heap, Fixed, Static, Small, MinMax | O(n) |
| **navigate tree** | `navigate.parent(of:)`, `navigate.child(_:of:)`, `navigate.isValid(_:)` | ALL variants | O(1) |

### Present -- Beyond Canonical (Enrichments)

| Operation | API | Description |
|-----------|-----|-------------|
| Optional extraction | `var take: Element?` | Non-throwing drain-friendly extraction |
| Bounded push | `push(_:) -> Heap.Push.Outcome` | Fixed/Static: overflow-safe insert returning `.inserted` / `.overflow(Element)` |
| Truncate | `truncate(to:)` | Reduce count (Fixed, Static, Small) |
| Element access by index | `element(at:) -> Element?` | Bounds-checked positional access (Heap, Fixed) |
| Unordered view | `var unordered: Buffer<Element>.Linear` | O(n) copy of elements in heap order |
| Replace priority | `replacePriority(with:)` | Replace root + re-heapify (package) |
| Span access | `var span: Span<Element>` | Zero-copy read view (Fixed, Small) |
| Mutable span | `var mutableSpan: MutableSpan<Element>` | Mutable access with invariant warning (Fixed, Small) |
| Spill detection | `var isSpilled: Bool` | SBO diagnostic (Small only) |
| Sequence iteration | `Swift.Sequence`, `Sequence.Protocol` | For-in loops, stdlib algorithms |
| Drain | `drain(_:)`, `Sequence.Drain.Protocol` | Consuming iteration |
| forEach (borrowing) | `forEach(_ body:)` | ~Copyable-safe traversal |
| Equality/Hashing | `Equatable`, `Hashable` | Structural comparison (Heap, MinMax) |
| Array literal | `ExpressibleByArrayLiteral` | `[1, 2, 3]` syntax (Heap, MinMax) |
| Description | `CustomStringConvertible` | Debug output |

### Missing -- Should Add (Primitives Layer)

| Canonical Operation | Priority | Rationale |
|--------------------|---------:|-----------|
| **`init(_ elements:)` for Static** | Medium | Static has no Sequence initializer. Currently must push elements one-by-one. Floyd's heapify would be O(n) vs O(n log n). |
| **`init(_ elements:)` for Small** | Medium | Same as Static. Small has no Sequence initializer. |
| **`Heap.MinMax.Fixed` operations** | Medium | Struct declared with buffer, but push/pop/peek/take not implemented. Currently a stub. |
| **`Heap.MinMax.Static` operations** | Medium | Same -- declared with buffer, no operations. |
| **`Heap.MinMax.Small` operations** | Medium | Same -- declared with buffer, no operations. |
| **`Equatable` / `Hashable` for Fixed** | Low | Present on Heap and MinMax but missing from Fixed. Structural equality is straightforward. |
| **`Equatable` / `Hashable` for Static** | Low | Same. |
| **`Equatable` / `Hashable` for Small** | Low | Same. |
| **`ExpressibleByArrayLiteral` for Fixed** | Low | Present on Heap and MinMax but missing from Fixed (requires known capacity). May not be practical since capacity must be specified. |
| **`CustomStringConvertible` for Fixed, Static, Small** | Low | Present on Heap and MinMax but not on the bounded variants. |

### Missing -- Intentionally Absent (Higher Layer or Impractical)

| Canonical Operation | Layer | Rationale |
|--------------------|---------:|-----------|
| **decrease_key / increase_key** | Foundations (Layer 3) | Requires index-tracking handles (indirect map from element to position). This is a *composed* data structure (heap + handle map), not a primitive. Binary heaps without handles cannot efficiently support this -- it requires O(n) search to find the element. Fibonacci heaps or indexed priority queues belong at a higher layer. |
| **merge / union** | Foundations (Layer 3) | O(n) for binary heaps (must rebuild). Only efficient for mergeable heaps (binomial, Fibonacci, pairing). A merge primitive on binary heaps would be misleading about complexity. Higher-layer types can provide `Heap(lhs) + Heap(rhs)` if needed. |
| **contains(_:)** | Undecided | O(n) linear scan. Not heap-specific (any container can do this). Could be added as a convenience but is not part of the heap ADT. Already available via `Sequence` conformance for Copyable elements. |
| **sorted drain / sorted iterator** | Ergonomic | Already achievable via `while let e = heap.take { }` or `while let e = heap.min.take { }`. A dedicated type would add API surface for something trivially composed. |
| **Heap.Min / Heap.Max** (dedicated types) | Low priority | `Heap(order: .ascending)` and `Heap(order: .descending)` cover these use cases. Dedicated types would add static type safety (can't accidentally flip ordering) but duplicate the entire API surface. Currently stubs with `fatalError`. |
| **`init(order:minimumCapacity:)`** | Low priority | Allows pre-allocation hint. Minor optimization. Buffer.Linear handles growth internally. |

---

## Summary Table

| Category | Count | Assessment |
|----------|:-----:|-----------|
| Canonical operations present | 8/8 (single-ended), 6/6 (MinMax) | Full coverage for implemented variants |
| Enrichments beyond canonical | 15+ | Well-chosen for primitives layer |
| Missing -- should add (primitives) | 8 items | Mostly variant completeness (MinMax.Fixed/Static/Small, init for Static/Small) |
| Missing -- intentionally absent | 6 items | Correctly deferred to higher layers |
| Stub types (declared, not implemented) | 5 types | Heap.Min, Heap.Max, MinMax.Fixed, MinMax.Static, MinMax.Small |

---

## Outcome

**Status**: RECOMMENDATION

### Verdict

The package provides **complete canonical coverage** for the implemented variants (Heap, Heap.Fixed, Heap.Static, Heap.Small, Heap.MinMax). Every expected ADT operation -- insert, peek, extract, build, count, isEmpty -- is present with correct complexity guarantees.

### Primary Gap: Variant Completeness

The main deficiency is not missing operations on implemented types, but **unimplemented variants**:

1. **Heap.MinMax.Fixed** -- struct declared, buffer allocated, no operations
2. **Heap.MinMax.Static** -- struct declared, buffer allocated, no operations
3. **Heap.MinMax.Small** -- struct declared, buffer allocated, no operations
4. **Heap.Min / Heap.Max** -- stubs with fatalError

The MinMax bounded variants are the higher priority since the MinMax algorithms (`bubbleUp`, `trickleDownMin`, `trickleDownMax`, `heapify`) already exist on `Heap.MinMax` and would need to be duplicated (or shared via protocol) for each buffer variant, following the same pattern as the single-ended heap.

### Secondary Gap: Initializer Completeness

`Heap.Static` and `Heap.Small` lack `init(_ elements:)` Sequence initializers. Users must push elements one-by-one, losing the O(n) heapify benefit. This is straightforward to add following the `Heap.init(_ elements:order:)` pattern.

### Correctly Absent

`decrease_key` and `merge` are correctly absent from the primitives layer. These operations require composed infrastructure (handle maps, mergeable heap trees) that belongs at Foundations (Layer 3) or above.

---

## References

- Cormen, Leiserson, Rivest, Stein, "Introduction to Algorithms" -- Chapter 6 (Heapsort), Chapter 19 (Fibonacci Heaps)
- Atkinson, Sack, Santoro, Strothotte, "Min-Max Heaps and Generalized Priority Queues" (1986)
- `/Users/coen/Developer/swift-primitives/swift-heap-primitives/Research/heap-discipline-boundary-analysis.md`
