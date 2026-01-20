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

// MARK: - Hoisted Error Types (Module Level)
//
// Swift does not allow nested types inside generic types to be easily accessed.
// These error types are hoisted to module level and exposed via typealiases to
// provide the expected Nest.Name API (Heap.Bounded.Error, Heap.Inline.Error, etc.).
//
// This is a documented exception per [API-EXC-001] due to Swift language
// limitations with generic nested types.
//
// Use the typealias forms in your code:
// - Heap<Element>.Bounded.Error
// - Heap<Element>.Inline.Error
// - Heap<Element>.Small.Error

/// Hoisted namespace for Heap variant error types.
///
/// This namespace enum avoids compound identifiers like `__HeapBoundedError`
/// per [API-NAME-002], providing the preferred `__Heap.Bounded.Error` pattern.
///
/// - Note: Use the typealias forms (e.g., ``Heap/Bounded/Error``) in your code,
///   not this namespace directly.
public enum __Heap {
    /// Namespace for Heap.Bounded error types.
    public enum Bounded {
        /// Errors that can occur during bounded heap operations.
        ///
        /// ## Cases
        ///
        /// - ``__Heap/Bounded/Error/invalidCapacity``: The requested capacity is invalid (negative).
        /// - ``__Heap/Bounded/Error/empty``: An operation was attempted on an empty heap.
        ///
        /// - Note: Overflow is NOT an error case. Per [API-ERR-005/006], push operations
        ///   that consume an element and can fail use ``Heap/Bounded/Push/Outcome`` to
        ///   preserve the element on overflow.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// The requested capacity is invalid (negative).
            case invalidCapacity
            /// An operation was attempted on an empty heap.
            case empty
        }
    }

    /// Namespace for Heap.Inline error types.
    public enum Inline {
        /// Errors that can occur during inline heap operations.
        ///
        /// ## Cases
        ///
        /// - ``__Heap/Inline/Error/empty``: An operation was attempted on an empty heap.
        ///
        /// - Note: Overflow is NOT an error case. Per [API-ERR-005/006], push operations
        ///   that consume an element and can fail use ``Heap/Inline/Push/Outcome`` to
        ///   preserve the element on overflow.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// An operation was attempted on an empty heap.
            case empty
        }
    }

    /// Namespace for Heap.Small error types.
    public enum Small {
        /// Errors that can occur during small heap operations.
        ///
        /// ## Cases
        ///
        /// - ``__Heap/Small/Error/empty``: An operation was attempted on an empty heap.
        ///
        /// - Note: Small heaps grow to heap storage on overflow, so overflow is not possible.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// An operation was attempted on an empty heap.
            case empty
        }
    }
}

// MARK: - Hoisted Error CustomStringConvertible

extension __Heap.Bounded.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidCapacity:
            return "invalid capacity (negative)"
        case .empty:
            return "operation attempted on empty heap"
        }
    }
}

extension __Heap.Inline.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .empty:
            return "operation attempted on empty heap"
        }
    }
}

extension __Heap.Small.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .empty:
            return "operation attempted on empty heap"
        }
    }
}
