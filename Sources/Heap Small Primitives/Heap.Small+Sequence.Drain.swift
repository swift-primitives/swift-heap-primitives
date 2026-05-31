// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Property_Primitives
import Sequence_Primitives
public import Heap_Small_Primitive

// MARK: - Sequence.Drain.Protocol Conformance

extension Heap.Small: Sequence.Drain.`Protocol` where Element: Copyable & Comparison.`Protocol` {
    // drain(_ body:) method already exists in Heap.Small Copyable.swift (type module).
    // This extension declares conformance to the protocol.
}

// MARK: - Drain Property Accessor

extension Heap.Small where Element: Copyable & Comparison.`Protocol` {
    /// Drain tag namespace (value-generic Valued view).
    public enum Drain {
        public typealias View = Property<Sequence.Drain>.Inout.Typed<Element>.Valued<inlineCapacity>
    }

    /// Accessor for drain operations.
    public var drain: Drain.View {
        mutating _read { yield unsafe .init(&self) }
        mutating _modify {
            var view: Drain.View = unsafe .init(&self)
            yield &view
        }
    }
}
