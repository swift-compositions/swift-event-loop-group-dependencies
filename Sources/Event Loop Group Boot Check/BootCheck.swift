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

// WHY THIS IS AN EXECUTABLE AND NOT A TEST TARGET
//
// `\.mainEventLoopGroup`'s accessor binds one of three `Dependency.Values`
// subscript overloads at the accessor's own compile time, against the
// conformances visible in that module. If the `Witness.Key` (liveValue)
// conformance is not visible there, the accessor binds the
// `Witness.Key.Test` overload instead and every production read resolves
// `EmbeddedEventLoop` — silently, forever.
//
// `swift build` is blind to it — MEASURED, not assumed: the split
// configuration was constructed deliberately and compiled GREEN, because
// overload resolution succeeds in both arrangements; it just succeeds
// differently.
//
// `swift test` is NOT blind, contrary to what this comment first claimed.
// `Witness.Context.currentMode` returns `.live` when no scope has set a
// mode, and nothing calls `Dependency.Context.detect()` automatically — so
// an unscoped read inside the test target is a LIVE read, and the §4.2
// tripwire traps the split there too. The package's own test target does
// catch this.
//
// What this executable adds over the test target:
//   * it exercises a REAL socket bind on the resolved group, which no test
//     here does, and a fatal bind was the recorded production symptom;
//   * it runs as a standalone process in the shape an app boots in, with no
//     override registered — the configuration real consumers use, since
//     repotraffic and the tenthijeboonkkamp server both retired their
//     explicit `\.mainEventLoopGroup` overrides once the conformance was
//     co-located, and so have nothing masking a regression;
//   * it fails with a diagnostic naming the cause rather than a trap.
//
// Exit 0 = the accessor is bound to the live overload and the resolved group
// survives a real socket bind. Exit 1 = it is not; see the diagnostic.

import Dependencies
import Event_Loop_Group_Dependencies
import NIOCore
import NIOEmbedded
import NIOPosix

@main
struct BootCheck {
    static func main() async {
        @Dependency(\.mainEventLoopGroup) var group: any EventLoopGroup

        // `__DependencyContext`, not `Dependency.Context`: the latter is a
        // typealias nested in the generic `Dependency<Value>` wrapper, so
        // spelling it there leaves `Value` uninferrable.
        let mode = __DependencyContext.mode
        print("context mode:  \(mode)")
        print("resolved type: \(type(of: group))")

        // Guard the check's own premise before trusting its verdict: if this
        // binary is somehow running in test context, `embedded` is correct
        // and a failure below would be meaningless.
        guard "\(mode)" == "live" else {
            fail(
                """
                expected live context, got \(mode). The check's premise does \
                not hold, so its verdict would be meaningless. This is a \
                defect in how the check was invoked, not in the accessor \
                binding.
                """
            )
        }

        if group is EmbeddedEventLoop {
            fail(
                """
                \\.mainEventLoopGroup resolved EmbeddedEventLoop in LIVE \
                context.

                The accessor is bound to the Witness.Key.Test subscript \
                overload, which means the Witness.Key (liveValue) conformance \
                was NOT visible in the module that compiled the accessor. The \
                accessor, the Witness.Key conformance and the \
                Dependency.Key.Test conformance must live in one module — see \
                di-composition-root-design.md §4.3 rule 2 and the comment in \
                EventLoopGroup.swift. Left unfixed this is an app-boot \
                SIGSEGV, not a degradation.
                """
            )
        }

        guard group is MultiThreadedEventLoopGroup else {
            fail(
                """
                expected MultiThreadedEventLoopGroup in live context, got \
                \(type(of: group)). Not the known split-conformance \
                signature, but the live value is not what liveValue declares \
                either.
                """
            )
        }

        // The type assertion proves the BINDING. This proves the CONSEQUENCE:
        // the recorded symptom was a fatal bind in marketing's main, so
        // exercise a real socket rather than trusting the type alone.
        // Ephemeral port — never a fixed one; other lanes' servers are live
        // on this machine.
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(.backlog, value: 1)

        do {
            let channel = try await bootstrap.bind(host: "127.0.0.1", port: 0).get()
            let port = channel.localAddress?.port.map(String.init) ?? "unknown"
            print("bound 127.0.0.1:\(port) on the resolved group")
            try await channel.close()
        } catch {
            fail("bind failed on the resolved group: \(error)")
        }

        print("BOOT CHECK PASSED: live context, MultiThreadedEventLoopGroup, real bind")
    }

    static func fail(_ message: String) -> Never {
        print("BOOT CHECK FAILED: \(message)")
        exit(1)
    }
}
