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

public import Buffer_Linear_Primitives

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
