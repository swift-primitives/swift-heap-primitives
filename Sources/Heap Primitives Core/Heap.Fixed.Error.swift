//
//  Heap.Fixed.Error.swift
//  swift-heap-primitives
//
//  Created by Coen ten Thije Boonkkamp on 26/01/2026.
//

// MARK: - CustomStringConvertible

extension Heap.Fixed.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidCapacity:
            return "invalid capacity (negative)"
        case .empty:
            return "operation attempted on empty heap"
        }
    }
}
