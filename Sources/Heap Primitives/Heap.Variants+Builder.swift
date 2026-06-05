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
import Storage_Heap_Primitives
public import Heap_Fixed_Primitive
public import Heap_Static_Primitive
public import Heap_Small_Primitive
public import Buffer_Linear_Primitives

// MARK: - Variant `@Heap.Builder` DSL inits
//
// Each capacity variant carries a thin `init(@Heap.Builder …)` that drains the
// linear `Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Linear` accumulator (from the shared `@Heap.Builder`
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
        @Heap<Element>.Builder _ builder: () -> Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Linear
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


