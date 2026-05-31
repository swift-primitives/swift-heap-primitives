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
// Re-exports for Heap Primitive (the base dynamic binary-heap type module).
// Declares Heap (dynamic, growable) + Heap.Index / Heap.Navigate / Heap.Builder;
// re-exports the linear buffer backing the base type composes.

@_exported public import Buffer_Linear_Primitive
@_exported public import Buffer_Linear_Primitives
@_exported public import Comparison_Primitives
@_exported public import Index_Primitives
@_exported public import Property_Primitives
