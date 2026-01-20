// ===----------------------------------------------------------------------===//
// Container.Bounded.swift - TRIGGER CONDITION #4
// ===----------------------------------------------------------------------===//
//
// This extension file contains the `borrowing Element` closure that triggers
// the compiler bug when combined with:
// 1. Compound generic constraint (Element: ~Copyable & Protocol)
// 2. Nested type with UnsafeMutablePointer<Element>
// 3. Conditional Sequence conformance
//
// The `withMin` method below triggers the bug. Comment it out to compile.
// ===----------------------------------------------------------------------===//

extension Container.Bounded where Element: ~Copyable {
    @inlinable
    public var count: Int { _storage.header }

    @inlinable
    public var isEmpty: Bool { _storage.header == 0 }
}

extension Container.Bounded where Element: ~Copyable {
    @usableFromInline
    mutating func _swapElements(at i: Int, _ j: Int) {
        let ptr = unsafe _cachedPtr
        let temp = unsafe (ptr + i).move()
        unsafe (ptr + i).initialize(to: (ptr + j).move())
        unsafe (ptr + j).initialize(to: temp)
    }
}

// TRIGGER: This method with `(borrowing Element)` closure parameter
// causes the bug when in a separate file from the type declaration.
// Comment out to see the code compile successfully.
extension Container.Bounded where Element: ~Copyable {
    @inlinable
    public func withMin<R>(_ body: (borrowing Element) -> R) -> R? {
        guard count > 0 else { return nil }
        return body(unsafe _cachedPtr[0])
    }
}
