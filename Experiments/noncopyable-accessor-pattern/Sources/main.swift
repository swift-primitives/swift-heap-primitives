// MARK: - Nested Accessor Pattern with ~Copyable Containers
// ============================================================================
//
// Purpose: Verify whether the nested accessor pattern (API-NAME-002) is
//          compatible with ~Copyable containers per MEM-COPY-005.
//
// Hypothesis: Non-consuming nested accessor patterns are fundamentally
//             incompatible with ~Copyable containers because the accessor
//             struct must store a reference to the container, which requires
//             copying—impossible for ~Copyable types.
//
// Test Approach: [EXP-004a] Incremental Construction
//   V1: Copyable container with accessor pattern → should pass
//   V2: ~Copyable container with accessor pattern → should FAIL
//   V3: Conditional Copyable container with accessor in ~Copyable context → should FAIL
//
// Toolchain: swift-6.2-DEVELOPMENT-SNAPSHOT-2026-01-15-a
// Platform: macOS 15.3 (arm64)
//
// Result: CONFIRMED - Accessor pattern incompatible with ~Copyable containers
// Date: 2026-01-20
//
// Evidence:
//   V1: PASS - Copyable container with accessor compiles
//   V2: FAIL - error: stored property 'container' of 'Copyable'-conforming
//              struct 'Take' has non-Copyable type 'ContainerV2'
//   V3: FAIL - Same error when container is conditionally ~Copyable and
//              accessor extension uses `where Element: ~Copyable`
//
// Conclusion: The accessor pattern requires the accessor struct to hold the
//             container. For ~Copyable containers, this is impossible without
//             making the accessor also ~Copyable, which defeats the purpose.
//             Use compound methods (takeMin(), popMin()) for ~Copyable containers.
//
// Cross-references:
//   - MEM-COPY-005: Documents this limitation
//   - API-NAME-002: Nested accessor pattern requirement
//   - Heap.Bounded: Production code affected by this limitation
//
// ============================================================================

// MARK: - V1: Copyable Container with Accessor Pattern (PASS)

/// A simple Copyable container.
struct ContainerV1<Element> {
    var elements: [Element] = []

    mutating func push(_ element: Element) {
        elements.append(element)
    }
}

extension ContainerV1 {
    /// Accessor struct for optional removal operations.
    struct Take {
        var container: ContainerV1<Element>

        init(container: ContainerV1<Element>) {
            self.container = container
        }
    }

    /// Nested accessor property.
    var take: Take {
        _read { yield Take(container: self) }
        _modify {
            var proxy = Take(container: self)
            self = ContainerV1()
            defer { self = proxy.container }
            yield &proxy
        }
    }
}

extension ContainerV1.Take {
    var first: Element? {
        mutating get {
            guard !container.elements.isEmpty else { return nil }
            return container.elements.removeFirst()
        }
    }
}

// V1 Test: This compiles and works correctly
func testV1() {
    var c = ContainerV1<Int>()
    c.push(1)
    c.push(2)
    c.push(3)

    // Accessor pattern works for Copyable containers
    if let first = c.take.first {
        print("V1: Took \(first), remaining: \(c.elements.count)")
    }
}


// MARK: - V2: ~Copyable Container with Accessor Pattern (FAIL)

/// A ~Copyable container.
struct ContainerV2<Element: ~Copyable>: ~Copyable {
    // Simulating inline storage (like Heap.Inline)
    var _element: Element?
    var _count: Int = 0

    init() {
        self._element = nil
    }

    mutating func push(_ element: consuming Element) {
        self._element = consume element
        self._count += 1
    }
}

// UNCOMMENT TO SEE THE ERROR:
// This demonstrates the fundamental incompatibility.
//
// extension ContainerV2 where Element: ~Copyable {
//     /// Accessor struct - THIS CANNOT WORK
//     ///
//     /// The struct needs to hold ContainerV2, but ContainerV2 is ~Copyable.
//     /// A Copyable struct cannot hold a ~Copyable value.
//     struct Take {
//         var container: ContainerV2<Element>  // ERROR: stored property of
//                                              // 'Copyable'-conforming struct
//                                              // has non-Copyable type
//
//         init(container: ContainerV2<Element>) {
//             self.container = container
//         }
//     }
// }

// V2 Workaround: Use compound methods instead of accessor pattern
extension ContainerV2 where Element: ~Copyable {
    /// Compound method - the only viable pattern for ~Copyable containers.
    mutating func takeFirst() -> Element? {
        guard _count > 0 else { return nil }
        _count -= 1
        return _element.take()
    }
}

func testV2() {
    var c = ContainerV2<Int>()
    c.push(42)

    // Compound method works
    if let first = c.takeFirst() {
        print("V2: Took \(first) using compound method")
    }
}


// MARK: - V3: Conditional Copyable with Accessor in ~Copyable Context (FAIL)

/// A container that is Copyable only when Element is Copyable.
/// This mirrors Heap.Bounded's design.
struct ContainerV3<Element: ~Copyable>: ~Copyable {
    var _storage: [Int] = []  // Simplified; real impl uses ManagedBuffer
    var _count: Int = 0
}

/// Conditional Copyable conformance
extension ContainerV3: Copyable where Element: Copyable {}

// UNCOMMENT TO SEE THE ERROR:
// Even with conditional Copyable, the accessor in the ~Copyable extension fails.
//
// extension ContainerV3 where Element: ~Copyable {
//     struct Take {
//         var container: ContainerV3<Element>  // ERROR: When Element is ~Copyable,
//                                              // ContainerV3 is ~Copyable, and
//                                              // cannot be stored in Copyable Take
//     }
//
//     var take: Take {
//         _read { yield Take(container: self) }
//     }
// }

// V3 Observation: The accessor COULD work in an extension constrained to
// `where Element: Copyable`, but then ~Copyable elements lose access to it.
// This creates API inconsistency—exactly what we wanted to avoid.

extension ContainerV3 where Element: Copyable {
    struct Take {
        var container: ContainerV3<Element>  // Works because Element: Copyable
                                             // means ContainerV3 is Copyable
    }

    var take: Take {
        _read { yield Take(container: self) }
        _modify {
            var proxy = Take(container: self)
            self = ContainerV3()
            defer { self = proxy.container }
            yield &proxy
        }
    }
}

// V3 Workaround: Compound methods for ~Copyable, accessor for Copyable
// This is the design Heap.Bounded uses.
extension ContainerV3 where Element: ~Copyable {
    mutating func takeFirst() -> Int? {
        guard _count > 0 else { return nil }
        _count -= 1
        return _storage.isEmpty ? nil : _storage.removeFirst()
    }
}


// MARK: - Summary

/*
 FINDINGS:

 1. COPYABLE CONTAINERS: Accessor pattern works perfectly.
    - ContainerV1 demonstrates this with take.first

 2. ~COPYABLE CONTAINERS: Accessor pattern is IMPOSSIBLE.
    - The accessor struct must hold the container
    - A Copyable struct cannot hold a ~Copyable value
    - Making the accessor ~Copyable defeats its purpose (can't be passed freely)

 3. CONDITIONAL COPYABLE: Accessor works ONLY for Copyable elements.
    - ContainerV3 shows the trade-off
    - Accessor available when Element: Copyable
    - Compound methods required when Element: ~Copyable
    - This creates API divergence, but it's unavoidable

 RECOMMENDATION:

 For containers supporting ~Copyable elements:
 - Use compound methods: takeMin(), takeMax(), popMin(), popMax()
 - This violates API-NAME-002 but MEM-COPY-005 provides the exception
 - Document the divergence in API documentation

 For containers with only Copyable elements:
 - Use accessor pattern: take.min, take.max, pop.min(), pop.max()
 - Consistent with base Heap API

 This is the design Heap.Bounded, Heap.Inline, and Heap.Small use.
 */

// MARK: - Main

testV1()
testV2()
print("Experiment complete. See comments for V2/V3 error demonstrations.")
