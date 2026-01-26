//
//  File.swift
//  swift-heap-primitives
//
//  Created by Coen ten Thije Boonkkamp on 26/01/2026.
//

public import Range_Primitives
public import Pointer_Primitives

extension Heap.Storage where Element: ~Copyable {
    
    /// Creates empty storage with no capacity.
    @usableFromInline
    package static func create() -> Heap.Storage {
        let storage = Heap.Storage.create(minimumCapacity: 0) { _ in 0 }
        return unsafe unsafeDowncast(storage, to: Heap.Storage.self)
    }

    /// Creates storage with the specified minimum capacity.
    @usableFromInline
    package static func create(minimumCapacity: Int) -> Heap.Storage {
        let requestedCapacity = Swift.max(minimumCapacity, 4)
        let storage = Heap.Storage.create(minimumCapacity: requestedCapacity) { _ in 0 }
        return unsafe unsafeDowncast(storage, to: Heap.Storage.self)
    }

    /// Typed count for this storage.
    @usableFromInline
    package var count: Heap.Index.Count {
        Heap.Index.Count(__unchecked: header)
    }
    
    
    /// Returns pointer to element storage.
    @usableFromInline
    package var _elementsPointer: Pointer_Primitives.Pointer<Element>.Mutable {
        unsafe Pointer_Primitives.Pointer<Element>.Mutable(withUnsafeMutablePointerToElements { unsafe $0 })
    }

    /// Initializes element at the given index.
    @usableFromInline
    package func initialize(to element: consuming Element, at index: Heap.Index) {
        let ptr = unsafe withUnsafeMutablePointerToElements { unsafe $0 + index }
        unsafe ptr.initialize(to: element)
    }

    /// Moves element from the given index.
    @usableFromInline
    package func move(at index: Heap.Index) -> Element {
        unsafe withUnsafeMutablePointerToElements { elements in
            unsafe (elements + index).move()
        }
    }

    /// Deinitializes elements in the given range.
    @usableFromInline
    package func deinitialize(in range: Range.Lazy<Heap.Index>) {
        _ = unsafe withUnsafeMutablePointerToElements { elements in
            range.forEach { index in
                unsafe (elements + index).deinitialize(count: 1)
            }
        }
    }

    /// Moves all elements to new storage.
    @usableFromInline
    package func move(to newStorage: Heap.Storage, count: Heap.Index.Count) {
        guard count > .zero else { return }
        _ = unsafe withUnsafeMutablePointerToElements { old in
            unsafe newStorage.withUnsafeMutablePointerToElements { new in
                (0..<count).forEach { index in
                    unsafe (new + index).initialize(to: (old + index).move())
                }
            }
        }
    }
}

// MARK: - Copy-on-Write Storage Extensions (Copyable elements only)

extension Heap.Storage where Element: Copyable {
    /// Copies all elements to new storage (for CoW).
    @usableFromInline
    package func copy(to newStorage: Heap.Storage, count: Heap.Index.Count) {
        guard count > .zero else { return }
        _ = unsafe withUnsafeMutablePointerToElements { old in
            unsafe newStorage.withUnsafeMutablePointerToElements { new in
                (0..<count).forEach { index in
                    unsafe (new + index).initialize(to: old[index])
                }
            }
        }
    }

    /// Reads element at the given index.
    @usableFromInline
    package func read(at index: Heap.Index) -> Element {
        unsafe withUnsafeMutablePointerToElements { elements in
            unsafe elements[index]
        }
    }

    /// Writes element at the given index (assumes already initialized).
    @usableFromInline
    package func write(_ element: Element, at index: Heap.Index) {
        unsafe withUnsafeMutablePointerToElements { elements in
            unsafe (elements + index).pointee = element
        }
    }

    /// Swaps elements at two indices.
    @usableFromInline
    package func swap(at i: Heap.Index, _ j: Heap.Index) {
        unsafe withUnsafeMutablePointerToElements { elements in
            let ptrI = unsafe elements + i
            let ptrJ = unsafe elements + j
            let temp = unsafe ptrI.pointee
            unsafe (ptrI.pointee = ptrJ.pointee)
            unsafe (ptrJ.pointee = temp)
        }
    }
}
