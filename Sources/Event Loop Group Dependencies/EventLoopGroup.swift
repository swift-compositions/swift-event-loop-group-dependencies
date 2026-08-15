// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-event-loop-group-dependencies open
// source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the
// swift-event-loop-group-dependencies project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Dependencies
public import NIOCore
import NIOEmbedded
import NIOPosix

public enum MainEventLoopGroup {}

extension Dependency.Values {
    // REASON: the injectable event-loop-group boundary preserves the
    // heterogeneous live (`MultiThreadedEventLoopGroup`) vs. test
    // (`EmbeddedEventLoop`) conformers this dependency switches between;
    // `EventLoopGroup` is a NIO protocol type with no single concrete
    // spelling that covers both.
    // swiftlint:disable:next no_any_protocol_existential
    public var mainEventLoopGroup: any EventLoopGroup {
        get { self[MainEventLoopGroup.self] }
        set { self[MainEventLoopGroup.self] = newValue }
    }
}

// Accessor/conformance CO-LOCATION (di-composition-root-design.md §4.3
// rule 2): the `\.mainEventLoopGroup` accessor above binds its
// `self[MainEventLoopGroup.self]` subscript overload at THIS module's
// compile time. When the accessor's module saw only the Key.Test conformance
// (the liveValue conformance lived downstream in boiler), the accessor was
// permanently bound to the testValue-only overload — production reads
// resolved the single-threaded EmbeddedEventLoop and NIO crashed at boot
// (app boot SIGSEGV; marketing main's bind fatal). The key's WIDEST
// conformance must be visible here, so the Witness.Key (liveValue)
// conformance lives HERE, not in a downstream module.
//
// The declarations below and the accessor above move together or not at all.
// Splitting them across modules re-arms the trap, and A GREEN BUILD CANNOT
// SEE IT — measured, not assumed: the split configuration was constructed
// deliberately and compiled green, because overload resolution succeeds in
// both arrangements. What does catch it is a LIVE read: the §4.2 tripwire
// traps when this key resolves through the `Key.Test` overload in `.live`
// mode. `Witness.Context.currentMode` is `.live` unless a scope sets it, so
// the test target's unscoped read is such a read, and
// `event-loop-group-boot-check` is another that additionally exercises a
// real socket bind.
extension MainEventLoopGroup: Witness.Key {
    // REASON: see the injectable event-loop-group boundary note above —
    // `liveValue` must share the existential return type of the accessor
    // it overloads.
    // swiftlint:disable:next no_any_protocol_existential
    public static var liveValue: any EventLoopGroup { multithreaded }
}

extension MainEventLoopGroup: Dependency.Key.Test {
    // REASON: see the injectable event-loop-group boundary note above —
    // `testValue` must share the existential return type of the accessor
    // it overloads.
    // swiftlint:disable:next no_any_protocol_existential
    public static var testValue: any EventLoopGroup { embedded }
}

extension MainEventLoopGroup {
    // REASON: see the injectable event-loop-group boundary note above.
    // swiftlint:disable:next no_any_protocol_existential
    public static var embedded: any EventLoopGroup {
        EmbeddedEventLoop()
    }

    // REASON: see the injectable event-loop-group boundary note above.
    // swiftlint:disable:next no_any_protocol_existential
    public static var multithreaded: any EventLoopGroup {
        #if DEBUG
            return MultiThreadedEventLoopGroup(numberOfThreads: 1)
        #else
            return MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        #endif
    }
}
