// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-standards open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-standards project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

// MARK: - Hoisted Ordering Protocol

/// Comparison protocol for heap elements supporting `~Copyable` types.
///
/// Uses `borrowing` parameters to allow comparison without consuming elements.
/// This enables heaps to work with move-only types that cannot conform to
/// `Comparable` (which requires value parameter passing).
///
/// ## Conformance
///
/// For `~Copyable` types, implement `isLessThan` explicitly:
///
/// ```swift
/// struct FileHandle: ~Copyable, Heap.Ordering {
///     let fd: Int32
///
///     static func isLessThan(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
///         lhs.fd < rhs.fd
///     }
/// }
/// ```
///
/// For `Copyable & Comparable` types, conformance is automatic:
///
/// ```swift
/// extension Int: Heap.Ordering {}  // Uses < operator
/// ```
///
/// ## Design Rationale
///
/// This protocol is hoisted to module level (as `__HeapOrdering`) because Swift
/// does not allow protocols nested in generic contexts. The canonical API uses
/// the typealias `Heap.Ordering`.
///
/// ## SE-0499
///
/// This design mirrors SE-0499 (Comparable/Equatable for ~Copyable), which will
/// add borrowing overloads to the standard library. When SE-0499 is implemented,
/// this protocol may be deprecated in favor of `Comparable`.
///
/// - Note: Access this protocol via `Heap.Ordering`, not `__HeapOrdering`.
public protocol __HeapOrdering: ~Copyable {
    /// Returns `true` if `lhs` should be ordered before `rhs`.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side element.
    ///   - rhs: The right-hand side element.
    /// - Returns: `true` if `lhs < rhs` in the ordering.
    static func isLessThan(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool
}

// MARK: - Comparable Bridge

extension __HeapOrdering where Self: Comparable {
    /// Default implementation using the `<` operator.
    ///
    /// Types that conform to both `Comparable` and `Heap.Ordering` get this
    /// implementation automatically.
    @inlinable
    public static func isLessThan(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
        lhs < rhs
    }
}

// MARK: - Standard Library Conformances

extension Int: __HeapOrdering {}
extension Int8: __HeapOrdering {}
extension Int16: __HeapOrdering {}
extension Int32: __HeapOrdering {}
extension Int64: __HeapOrdering {}
extension UInt: __HeapOrdering {}
extension UInt8: __HeapOrdering {}
extension UInt16: __HeapOrdering {}
extension UInt32: __HeapOrdering {}
extension UInt64: __HeapOrdering {}
extension Float: __HeapOrdering {}
extension Double: __HeapOrdering {}
extension String: __HeapOrdering {}
extension Character: __HeapOrdering {}
