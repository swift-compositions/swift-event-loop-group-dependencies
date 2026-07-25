# swift-event-loop-group-dependencies

The process's main NIO event loop group as a dependency value.

```swift
@Dependency(\.mainEventLoopGroup) var group
```

`.live` resolves a `MultiThreadedEventLoopGroup`; `testValue` is an
`EmbeddedEventLoop`. Register an explicit value in the composition root to
override either.

## Why the accessor and both witnesses live in one module

`Dependency.Values` declares three subscript overloads, and the accessor
binds one of them **at the accessor's own compile time**, against the
conformances visible in that module. If the `Witness.Key` (liveValue)
conformance is not visible there, the accessor binds the `Key.Test` overload
and every production read resolves the single-threaded `EmbeddedEventLoop`.

That is not hypothetical. It shipped once, with the accessor in
swift-server-foundation and the liveValue conformance downstream in boiler:
production resolved the embedded group and NIO crashed at boot. The rule is
`di-composition-root-design.md` §4.3 rule 2 — *an accessor MUST be compiled in
the module that sees the key's widest conformance* — and it is why
`MainEventLoopGroup`, the accessor, the `Witness.Key` conformance and the
`Dependency.Key.Test` conformance are one file in one module here.

**A green build cannot see a split.** That was measured, not assumed: the
split configuration was constructed deliberately and compiled green, because
overload resolution succeeds in both arrangements — it just succeeds
differently.

What catches it is a **live read**. `Witness.Context.currentMode` is `.live`
unless a scope sets one, so the §4.2 tripwire traps a split as soon as the key
is resolved — including from this package's own test target.

## `event-loop-group-boot-check`

```bash
swift run event-loop-group-boot-check
```

A standalone executable that resolves the accessor with no override
registered, asserts the group is a `MultiThreadedEventLoopGroup`, and then
**binds a real socket on an ephemeral port** — a fatal bind was the recorded
production symptom, and a type assertion alone would not have caught it. Exits
non-zero with a diagnostic naming the cause.

It is verified against the failure it exists to catch: run against a
deliberately split configuration it exits non-zero, and against the correct
one it exits zero.
