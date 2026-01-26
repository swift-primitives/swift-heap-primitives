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

// MARK: - Hoisted Error Types (Module Level)
//
// Swift does not allow nested types inside generic types to be easily accessed.
// These error types are hoisted to module level and exposed via typealiases to
// provide the expected Nest.Name API (Heap.Error, etc.).
//
// This is a documented exception per [API-EXC-001] due to Swift language
// limitations with generic nested types.
//
// Use the typealias forms in your code:
// - Heap.Error
// - Heap.Fixed.Error
// - Heap.Static.Error
// - Heap.Small.Error

/// Hoisted namespace for Heap variant error types.
///
/// This namespace enum avoids compound identifiers like `__HeapError`
/// per [API-NAME-002], providing the preferred `__Heap.Error` pattern.
///
/// - Note: Use the typealias forms (e.g., ``Heap/Error``) in your code,
///   not this namespace directly.
public enum __Heap {
    /// Errors that can occur during heap operations.
    ///
    /// ## Cases
    ///
    /// - ``__Heap/Error/empty``: An operation was attempted on an empty heap.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// An operation was attempted on an empty heap.
        case empty
    }

    /// Namespace for Heap.Fixed error types.
    public enum Fixed {
        /// Errors that can occur during fixed heap operations.
        ///
        /// ## Cases
        ///
        /// - ``__Heap/Fixed/Error/invalidCapacity``: The requested capacity is invalid (negative).
        /// - ``__Heap/Fixed/Error/empty``: An operation was attempted on an empty heap.
        ///
        /// - Note: Overflow is NOT an error case. Per [API-ERR-005/006], push operations
        ///   that consume an element and can fail use `Push.Outcome` to preserve the element on overflow.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// The requested capacity is invalid (negative).
            case invalidCapacity
            /// An operation was attempted on an empty heap.
            case empty
        }
    }

    /// Namespace for Heap.Static error types.
    public enum Static {
        /// Errors that can occur during static heap operations.
        ///
        /// ## Cases
        ///
        /// - ``__Heap/Static/Error/empty``: An operation was attempted on an empty heap.
        ///
        /// - Note: Overflow is NOT an error case. Per [API-ERR-005/006], push operations
        ///   that consume an element and can fail use `Push.Outcome` to preserve the element on overflow.
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

extension __Heap.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .empty:
            return "operation attempted on empty heap"
        }
    }
}

extension __Heap.Fixed.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidCapacity:
            return "invalid capacity (negative)"
        case .empty:
            return "operation attempted on empty heap"
        }
    }
}

extension __Heap.Static.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .empty:
            return "operation attempted on empty heap"
        }
    }
}

