// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-standards open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-standards project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Property_Primitives

extension Heap where Element: Copyable {
    /// Shorthand for `Property_Primitives.Property<Tag, Heap<Element>>`.
    ///
    /// Used for method-based accessors where generic where clauses work.
    public typealias Property<Tag> = Property_Primitives.Property<Tag, Heap<Element>>
}
