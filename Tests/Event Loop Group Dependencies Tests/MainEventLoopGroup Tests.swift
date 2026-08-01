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

import Dependencies
import NIOCore
import NIOEmbedded
import NIOPosix
import Testing

@testable import Event_Loop_Group_Dependencies

extension MainEventLoopGroup {
    @Suite("MainEventLoopGroup")
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension MainEventLoopGroup.Test.Integration {
    /// `Witness.Context.currentMode` returns `.live` when no scope has set a
    /// mode, and nothing calls `Dependency.Context.detect()` automatically —
    /// so an unscoped read inside the test target resolves the LIVE value,
    /// not `testValue`. That makes this a genuine co-location assertion: were
    /// the `Witness.Key` conformance to stop being visible to the accessor's
    /// module, this read would route through the `Key.Test` overload and the
    /// §4.2 tripwire would trap the run.
    @Test
    func `an unscoped read resolves the live value`() {
        @Dependency(\.mainEventLoopGroup) var group
        #expect(group is MultiThreadedEventLoopGroup)
        #expect(!(group is EmbeddedEventLoop))
    }

    @Test
    func `an explicit override wins over the context default`() {
        let injected = EmbeddedEventLoop()
        withDependencies {
            $0.mainEventLoopGroup = injected
        } operation: {
            @Dependency(\.mainEventLoopGroup) var group
            #expect(group is EmbeddedEventLoop)
        }
    }

    /// Both conformances must be visible from this module. If either is
    /// missing the package no longer satisfies §4.3 rule 2.
    @Test
    func `declares both the live and the test witness`() {
        #expect(MainEventLoopGroup.liveValue is MultiThreadedEventLoopGroup)
        #expect(MainEventLoopGroup.testValue is EmbeddedEventLoop)
    }
}
