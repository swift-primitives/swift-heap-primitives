//
//  File.swift
//  swift-heap-primitives
//
//  Created by Coen ten Thije Boonkkamp on 26/01/2026.
//

extension __Heap {
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
}

extension Heap.Static {
    /// Errors that can occur during static heap operations.
    public typealias Error = __Heap.Static.Error
}

extension __Heap.Static.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .empty:
            return "operation attempted on empty heap"
        }
    }
}

