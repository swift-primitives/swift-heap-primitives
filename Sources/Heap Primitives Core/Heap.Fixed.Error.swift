//
//  File.swift
//  swift-heap-primitives
//
//  Created by Coen ten Thije Boonkkamp on 26/01/2026.
//

extension __Heap {
    
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
}

extension Heap.Fixed {
    /// Errors that can occur during fixed heap operations.
    public typealias Error = __Heap.Fixed.Error
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
