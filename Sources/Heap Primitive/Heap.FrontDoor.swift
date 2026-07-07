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

public import Buffer_Linear_Primitive
public import Buffer_Primitive
public import Memory_Allocator_Primitive
public import Memory_Heap_Primitives
public import Storage_Contiguous_Primitives

// MARK: - Heap<E> — the CANONICAL front door ([DS-028])

/// A binary min priority queue over the default column: the heap-allocated, move-only
/// contiguous linear buffer.
///
/// This is the canonical front-door alias ([DS-028]) — the sanctioned [API-NAME-004]
/// generic-instantiation exception that pins the default column so consumers spell
/// `Heap<Element>`, never the carrier `__Heap` or a full column. The alias fully
/// specializes: conformances, the pinned constructors, and `~Copyable` elements all flow
/// through it with zero forwarding and zero runtime cost (the worked example measured
/// zero `witness_method` dispatch on tower ops in the -O cross-module client SIL).
///
/// ```swift
/// var h = Heap<Int>(minimumCapacity: 4)   // growable move-only min-heap (this alias)
/// h.push(5); h.push(1); h.push(3)
/// let smallest = h.min                    // 1  (O(1))
/// let removed = h.pop()                   // 1  (O(log n))
/// ```
///
/// The element must be `Comparison.Protocol` for the ordering ops (push/pop/min/sift);
/// `~Copyable` elements are fully supported (a move-only `Job: Comparison.Protocol`
/// flows through push/pop/min).
///
/// Variants are consumer-pulled and land as they gain live consumers (the
/// allocation `Small<n>` inline-budget variant, the `Shared` CoW column). None ship
/// today — no live consumer pulls them ([DS-028] consumer-pulled discipline).
public typealias Heap<E: ~Copyable> =
    __Heap<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear>
