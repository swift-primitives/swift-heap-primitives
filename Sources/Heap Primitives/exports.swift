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
// Re-export internal modules for consumers.
// Users import Heap_Primitives and get the binary-heap discipline: the base
// Heap type + conformances (this module), plus every storage variant
// (Fixed / Static / Small), the single-ended Min / Max stubs, and the
// double-ended MinMax heap. Per [MOD-005] the base-ops plural doubles as the
// package umbrella.

@_exported public import Heap_Primitive
@_exported public import Heap_Fixed_Primitives
@_exported public import Heap_Static_Primitives
@_exported public import Heap_Small_Primitives
@_exported public import Heap_Min_Primitives
@_exported public import Heap_Max_Primitives
@_exported public import Heap_MinMax_Primitives
