// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Heap_Primitive
public import Heap_Fixed_Primitive
public import Heap_Static_Primitive
public import Heap_Small_Primitive
public import Buffer_Linear_Primitives

// MARK: - Variant `@Heap.Builder` DSL inits
//
// Each capacity variant carries a thin `init(@Heap.Builder …)` that drains the
// linear `Buffer<Element>.Linear` accumulator (from the shared `@Heap.Builder`
// grammar) through the variant's own `push`. Centralized here in the base ops
// module (mirroring stack/set-ordered's Variants+Builder) because `Heap.Builder`
// lives in this module while the variant types live in their own type modules.

extension Heap.Fixed where Element: ~Copyable {
    /// Constructs a heap-allocated bounded heap from a result-builder closure.
    ///
    /// Wraps the dynamic `Heap<Element>.Builder` per Round-2 Option Y.
    /// Capacity at outer init; Outcome-return overflow converted to typed
    /// throw per OQ1a.
    public init(
        capacity: Int,
        order: Heap<Element>.Order = .ascending,
        @Heap<Element>.Builder _ builder: () -> Buffer<Element>.Linear
    ) throws(Self.Error) {
        var fixed = try Heap<Element>.Fixed(capacity: capacity, order: order)
        var buffer = builder()
        while !buffer.isEmpty {
            let outcome = fixed.push(buffer.remove.first())
            switch consume outcome {
            case .inserted:
                break
            case .overflow(let returned):
                _ = consume returned
                throw .overflow
            }
        }
        self = fixed
    }
}

extension Heap.Static where Element: ~Copyable {
    /// Constructs a fixed-capacity inline heap from a result-builder closure.
    ///
    /// Wraps the dynamic `Heap<Element>.Builder` per Round-2 Option Y.
    /// Order parameter binds at the outer init. Per OQ1a, push's
    /// Outcome-return overflow is converted to a typed throw at this
    /// boundary.
    public init(
        order: Heap<Element>.Order = .ascending,
        @Heap<Element>.Builder _ builder: () -> Buffer<Element>.Linear
    ) throws(Self.Error) {
        var buffer = builder()
        self.init(order: order)
        while !buffer.isEmpty {
            let outcome = self.push(buffer.remove.first())
            switch consume outcome {
            case .inserted:
                break
            case .overflow(let returned):
                _ = consume returned
                throw .overflow
            }
        }
    }
}

extension Heap.Small where Element: ~Copyable {
    /// Constructs a SmallVec heap from a result-builder closure.
    ///
    /// Wraps the dynamic `Heap<Element>.Builder` per Round-2 Option Y.
    /// Non-throwing because Small spills inline capacity to the heap.
    public init(
        order: Heap<Element>.Order = .ascending,
        @Heap<Element>.Builder _ builder: () -> Buffer<Element>.Linear
    ) {
        var buffer = builder()
        self.init(order: order)
        while !buffer.isEmpty {
            self.push(buffer.remove.first())
        }
    }
}
