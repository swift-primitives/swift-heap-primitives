//
//  File.swift
//  swift-heap-primitives
//
//  Created by Coen ten Thije Boonkkamp on 26/01/2026.
//

extension __Heap {
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

extension Heap.Small {
    /// Errors that can occur during small heap operations.
    public typealias Error = __Heap.Small.Error
}

extension __Heap.Small.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .empty:
            return "operation attempted on empty heap"
        }
    }
}
