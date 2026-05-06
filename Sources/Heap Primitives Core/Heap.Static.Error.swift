//
//  Heap.Static.Error.swift
//  swift-heap-primitives
//
//  Created by Coen ten Thije Boonkkamp on 26/01/2026.
//

// MARK: - CustomStringConvertible

extension Heap.Static.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .empty:
            return "operation attempted on empty heap"
        case .overflow:
            return "heap is full"
        }
    }
}
