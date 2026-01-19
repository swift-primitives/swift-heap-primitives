// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-standards open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-standards project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

extension Heap {
    /// Typed error for Heap operations.
    ///
    /// Uses typed throws (`throws(Heap.Error)`) for compile-time exhaustiveness.
    ///
    /// ## Example
    ///
    /// ```swift
    /// do {
    ///     let min = try heap.pop.min()
    /// } catch .empty {
    ///     print("Heap was empty")
    /// }
    /// ```
    public enum Error: Swift.Error, Sendable, Equatable {
        /// An operation was attempted on an empty heap.
        case empty(Empty)
    }
}

// MARK: - Error Payloads

extension Heap.Error {
    /// Empty collection payload.
    public struct Empty: Sendable, Equatable {
        @inlinable
        public init() {}
    }
}

// MARK: - CustomStringConvertible

extension Heap.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .empty: return "operation attempted on empty heap"
        }
    }
}
