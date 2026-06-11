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
public import Column_Primitives
import Storage_Contiguous_Primitives
// Internal: the init bodies (not inlinable) reach Fixed.push / the column's
// remove view through these; the signatures only name Heap_Primitive +
// Column_Primitives types.
internal import Heap_Fixed_Primitive
internal import Buffer_Linear_Primitives

// MARK: - Variant `@Heap.Builder` DSL inits
//
// Each capacity variant carries a thin `init(@Heap.Builder …)` that drains the
// linear `Column.Heap<Element>` accumulator (from the shared `@Heap.Builder`
// grammar) through the variant's own `push`. Centralized here in the base ops
// module (mirroring stack/set-ordered's Variants+Builder) because `Heap.Builder`
// lives in this module while the variant types live in their own type modules.
//
// The init twins split on element copyability (the constructing-twin
// treatment): the inner `Heap<Element>.Fixed(capacity:order:)` call resolves
// per lane — the `Copyable` twin binds the clone-capturing constructor, so the
// escaping heap's CoW box can restore uniqueness.

extension Heap.Fixed where Element: ~Copyable {
    /// Constructs a heap-allocated bounded heap from a result-builder closure.
    ///
    /// Wraps the dynamic `Heap<Element>.Builder` per Round-2 Option Y.
    /// Capacity at outer init; Outcome-return overflow converted to typed
    /// throw per OQ1a.
    public init(
        capacity: Int,
        order: Heap<Element>.Order = .ascending,
        @Heap<Element>.Builder _ builder: () -> Column.Heap<Element>
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

extension Heap.Fixed where Element: Copyable {
    /// Constructs a heap-allocated bounded heap from a result-builder closure
    /// (the `Copyable` constructing twin — the inner `Fixed(capacity:order:)`
    /// resolves to the clone-capturing constructor, so the escaping heap's
    /// CoW box can restore uniqueness).
    ///
    /// Capacity at outer init; Outcome-return overflow converted to typed
    /// throw per OQ1a.
    public init(
        capacity: Int,
        order: Heap<Element>.Order = .ascending,
        @Heap<Element>.Builder _ builder: () -> Column.Heap<Element>
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
