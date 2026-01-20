# Swift Compiler Bug: ~Copyable Constraint Propagation Failure

**Date**: 2026-01-20
**Swift Version**: 6.2.3
**Status**: Confirmed - Minimal Reproduction Created

## Summary

A Swift compiler bug causes `~Copyable` constraint propagation to fail during module emission (`-emit-module`) under specific conditions. The error message is:

```
error: type 'Element' does not conform to protocol 'Copyable'
var _cachedPtr: UnsafeMutablePointer<Element>
```

## Exact Trigger Conditions

**ALL of the following conditions must be present:**

1. **Compound generic constraint**: `Element: ~Copyable & Protocol`
   - Single constraint (`Element: ~Copyable`) does NOT trigger the bug

2. **Nested type with unsafe pointer**: `UnsafeMutablePointer<Element>` stored property

3. **Conditional Sequence conformance**: `extension Type: Sequence where Element: Copyable`
   - Other conditional conformances (custom protocols) do NOT trigger the bug

4. **Extension file with borrowing closure**: A separate `.swift` file containing a method with `(borrowing Element)` closure parameter
   - Same method in the main type file does NOT trigger the bug

## Reproduction

```bash
cd Experiments/noncopyable-sequence-bug
swift build  # Fails with the error
```

To see it compile successfully, comment out the `withMin` method in `Container.Bounded.swift`.

## Workarounds

### Option 1: Disable Sequence Conformance (Current Heap Implementation)
```swift
// Disable Sequence, provide forEach alternative
extension Heap.Bounded where Element: ~Copyable {
    public func forEach(_ body: (borrowing Element) -> Void) { ... }
}
```

### Option 2: Move Borrowing Methods to Main File
```swift
// In Heap.swift (same file as Heap.Bounded declaration)
extension Heap.Bounded where Element: ~Copyable {
    public func withMin<R>(_ body: (borrowing Element) -> R) -> R? { ... }
}
```

## Files

- `Container.swift`: Main type with Sequence conformance (triggers bug)
- `Container.Bounded.swift`: Extension file with borrowing Element closure (triggers bug)
- `Package.swift`: Swift 6.2 with Lifetimes experimental feature

## Impact

- Affects all library builds using `~Copyable` with compound constraints and Sequence
- Swift Package Manager uses `-emit-module` by default
- Prevents standard iteration patterns for move-only data structures

## Category

This is a **Category 4** failure mode beyond the MEM-COPY-006 documented patterns:
- Category 1: Nested types in extensions
- Category 2: Implicit Copyable constraints
- Category 3: Protocol conformances in separate files
- **Category 4**: Module emission phase constraint solver failure with Sequence + borrowing closures

## Bug Report Information

## Swift Issue

Filed as [swiftlang/swift#86669](https://github.com/swiftlang/swift/issues/86669)

Reproduction repository: https://github.com/coenttb/swift-issue-emit-module-noncopyable-sequence
