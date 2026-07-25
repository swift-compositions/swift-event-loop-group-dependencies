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
import Testing

@testable import Event_Loop_Group_Dependencies

@Suite("MainEventLoopGroup")
struct MainEventLoopGroupTests {
    /// In test context the accessor is expected to resolve `testValue`. This
    /// is the correct answer here and NOT evidence about the live binding —
    /// `event-loop-group-boot-check` is the only gate that can speak to that.
    @Test("resolves the embedded group in test context")
    func `resolves the embedded group in test context`() {
        @Dependency(\.mainEventLoopGroup) var group
        #expect(group is EmbeddedEventLoop)
    }

    @Test("an explicit override wins over the context default")
    func `an explicit override wins over the context default`() {
        let injected = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        withDependencies {
            $0.mainEventLoopGroup = injected
        } operation: {
            @Dependency(\.mainEventLoopGroup) var group
            #expect(group is MultiThreadedEventLoopGroup)
        }
    }

    /// Both conformances must be visible from this module. If either is
    /// missing the package no longer satisfies §4.3 rule 2, and the failure
    /// mode is silent at every other gate.
    @Test("declares both the live and the test witness")
    func `declares both the live and the test witness`() {
        #expect(MainEventLoopGroup.liveValue is MultiThreadedEventLoopGroup)
        #expect(MainEventLoopGroup.testValue is EmbeddedEventLoop)
    }
}
