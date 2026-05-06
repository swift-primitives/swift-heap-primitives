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

extension Heap.Static where Element: ~Copyable {
    /// Constructs a fixed-capacity inline heap from a result-builder closure.
    ///
    /// Wraps the dynamic `Heap<Element>.Builder` per Round-2 Option Y.
    /// Order parameter binds at the outer init. Per OQ1a, push's
    /// Outcome-return overflow is converted to a typed throw at this
    /// boundary.
    public init(
        order: Heap<Element>.Order = .ascending,
        @Heap<Element>.Builder _ builder: () -> Buffer<Element>.Linear
    ) throws(Error) {
        var buffer = builder()
        self.init(order: order)
        while !buffer.isEmpty {
            let outcome = self.push(buffer.remove.first())
            switch consume outcome {
            case .inserted:
                break
            case .overflow(let returned):
                _ = consume returned
                throw .overflow
            }
        }
    }
}
