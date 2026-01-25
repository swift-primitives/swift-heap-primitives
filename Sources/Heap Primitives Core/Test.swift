// Minimal test to isolate ~Copyable propagation issue

public struct TestHeap<Element: ~Copyable>: ~Copyable {

    // Storage class with extra methods (matching Heap.Storage)
    @usableFromInline
    package final class Storage: ManagedBuffer<Int, Element> {

        @usableFromInline
        package static func create() -> Storage {
            let storage = Storage.create(minimumCapacity: 0) { _ in 0 }
            return unsafe unsafeDowncast(storage, to: Storage.self)
        }

        @usableFromInline
        package static func create(minimumCapacity: Int) -> Storage {
            let requestedCapacity = Swift.max(minimumCapacity, 4)
            let storage = Storage.create(minimumCapacity: requestedCapacity) { _ in 0 }
            return unsafe unsafeDowncast(storage, to: Storage.self)
        }

        deinit {
            let count = header
            guard count > 0 else { return }
            _ = unsafe withUnsafeMutablePointerToElements { elements in
                for i in 0..<count {
                    unsafe (elements + i).deinitialize(count: 1)
                }
            }
        }

        @usableFromInline
        package var _elementsPointer: UnsafeMutablePointer<Element> {
            unsafe withUnsafeMutablePointerToElements { unsafe $0 }
        }
    }

    // Nested struct
    public struct Fixed: ~Copyable {
        @usableFromInline
        var _storage: TestHeap.Storage

        public let capacity: Int

        @usableFromInline
        package var _cachedPtr: UnsafeMutablePointer<Element> {
            unsafe _storage.withUnsafeMutablePointerToElements { unsafe $0 }
        }
    }

    // Static (to match Heap)
    public struct Static<let capacity: Int>: ~Copyable {
        @usableFromInline
        package var _count: Int

        @usableFromInline
        package var _storage: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>
    }
}
