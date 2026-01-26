//
//  File.swift
//  swift-heap-primitives
//
//  Created by Coen ten Thije Boonkkamp on 26/01/2026.
//



extension Heap.MinMax.Small {
    
    /// Whether the heap is currently using heap storage.
    @inlinable
    public var isSpilled: Bool { heap != nil }

    /// Spills inline storage to heap.
    @usableFromInline
    package mutating func spillToHeap(minimumCapacity: Int) {
        precondition(heap == nil, "Already spilled")

        let newCapacity = Swift.max(minimumCapacity, inlineCapacity * 2, 8)
        let newStorage = Heap.Storage.create(minimumCapacity: newCapacity)
        newStorage.header = count.rawValue

        inline.move(to: newStorage, count: count)

        heap = newStorage
        unsafe (heapPtr = newStorage._elementsPointer)
    }
}
