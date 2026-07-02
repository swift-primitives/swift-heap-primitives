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

// exports.swift
// The package umbrella ([MOD-005]): consumers import `Heap_Primitives` and get the
// binary min-heap ADT — the bound-free carrier `__Heap<S>` + the canonical front
// door `Heap<E>` (the ADT-tower W2 shape).
//
// The former Min / Max single-ended stubs are DELETED (they were non-functional
// `fatalError` placeholders; min IS the canonical `Heap`). `Heap.MinMax` is PARKED
// (see "Experiments/Heap MinMax (parked)/") as a future sibling for the heap-template
// round — deleting the stubs did NOT delete the MinMax plan.

@_exported public import Heap_Primitive
