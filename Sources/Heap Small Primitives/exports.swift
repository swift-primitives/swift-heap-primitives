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

// Re-export core types
@_exported public import Heap_Primitives_Core

// Note: Heap.Small is unconditionally ~Copyable (due to deinit requirement),
// so it cannot conform to Swift.Sequence which requires Copyable.
// Use forEach { } for iteration instead of for-in loops.
