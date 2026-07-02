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
// Re-exports for Heap Primitive — the ADT-tower carrier module.
// Declares the bound-free carrier `__Heap<S: ~Copyable>` (Heap.swift) + the
// canonical front-door alias `Heap<E>` (Heap.FrontDoor.swift, [DS-028]);
// re-exports the seams + the default linear/heap column vocabulary the front
// door and the seam-generic ops compose.

@_exported public import Comparison_Primitives
@_exported public import Store_Protocol_Primitives
@_exported public import Buffer_Protocol_Primitives
@_exported public import Buffer_Primitive
@_exported public import Buffer_Linear_Primitive
@_exported public import Storage_Contiguous_Primitives
@_exported public import Memory_Heap_Primitives
@_exported public import Memory_Allocator_Primitive
@_exported public import Index_Primitives
