# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test

```bash
swift build          # build the library
swift test           # run all tests (28 tests)
swift test --filter TinyReduxTests.PipelineTests/completeTriggersOnLog  # run a single test
```

Swift 6.0 toolchain required. Strict Concurrency is enforced (`swiftLanguageModes: [.version("6")]`).

## Architecture

TinyRedux is a **Supervised Redux Model** — a unidirectional data flow framework where middleware, resolver, and reducer cooperate in the same dispatch pipeline.

### Dispatch Pipeline

```
dispatch(action)  [nonisolated — callable from any isolation]
    ↓
Dispatcher (actor) → EventBus (AsyncStream bridge)
    ↓
Store.worker Task (MainActor) reads stream
    ↓
Middleware chain (reversed order, sync — async work via context.task)
    ├─ can dispatch, transform, block, or forward actions
    ├─ throws → error routed to resolver chain
    └─ calls context.next() to continue
        ↓
Reducer chain (forward order, MainActor — pure state mutations)
    ↓
If middleware threw:
Resolver chain (reversed order, non-throwing — error recovery)
    ├─ can dispatch recovery actions
    └─ calls context.next() to forward error
```

Key: middlewares and resolvers are **reversed** at init so the first element in the user-supplied array runs first in the chain. Reducers run in forward order.

### Core Types

| Protocol | Role | Context struct |
|---|---|---|
| `Middleware` | Async side effects, throws | `MiddlewareContext` |
| `Reducer` | Pure state mutation (O(1), MainActor) | `ReducerContext` |
| `Resolver` | Error recovery, non-throwing | `ResolverContext` |

Each has a type-erased `Any*` wrapper (`AnyMiddleware`, `AnyReducer`, `AnyResolver`). Note: `AnyReducer` does **not** conform to the `Reducer` protocol — it's closure-based.

**Store** (`@MainActor @Observable @dynamicMemberLookup`) — central hub holding state + pipeline. Read-only state access via `subscript(dynamicMember:)`. Optional `onLog` callback for timing/diagnostics.

**ReduxState** — mutable observable state with a `ReadOnly` associated type projection (`ReduxReadOnlyState`). Middlewares and resolvers only see `ReadOnly`; reducers get the mutable state.

### Context Pattern

All contexts are `@frozen struct` + `Sendable`. They expose:
- `.args` for destructured access (e.g., `let (dispatch, resolve, task, next, action) = context.args`)
- `.next()` guarded by `OnceGuard` (idempotent, second call is no-op)
- `.complete()` guarded by `OnceGuard` (emits timing via `onLog` when enabled)

### Utilities

- **OnceGuard** — `NSLock`-based one-shot guard for idempotent `next()`/`complete()` calls
- **EventBus** — generic `AsyncStream` bridge with flush/finish lifecycle; buffering policy `.bufferingOldest(256)`
- **Dispatcher** — actor wrapping EventBus for serialized action dispatch
- **Singleton** — `@MainActor` type-keyed instance cache for Store lifecycle

## Conventions

- All public types must be `Sendable`. Context structs are `@frozen`.
- `ContinuousClock` for timing (not `DispatchTime`). `Duration` for elapsed time.
- Property sort order: `@Wrapped`, then by access level (open → public → internal → private), `let` before `var`, instance before static.
- SwiftUI views: separate `struct` for properties, `extension: View` for body, nested private `Content` struct.
- Tests use Swift Testing framework (`@Test`, `#expect`), not XCTest.
- Indentation: 2 spaces, no tabs. Preserve the existing code structure and formatting style — match surrounding code when editing (brace placement, blank lines between sections, closure layout, parameter alignment).

## Current Session Context

Implemented `context.complete()` + `onLog` callback across the entire pipeline:

1. **Store.Log** (`Store+Log.swift`) — enum with three cases:
   - `.middleware(id:, action:, elapsed:, succeeded:, error:)` — error is optional (`SendableError?`)
   - `.reducer(id:, action:, elapsed:, succeeded:)`
   - `.resolver(id:, action:, elapsed:, succeeded:, error:)` — error is always present (`SendableError`)

2. **`complete()` on all contexts** — each context (`MiddlewareContext`, `ReducerContext`, `ResolverContext`) gained `_complete` + `_completeGuard` (OnceGuard). When `onLog` is nil, `complete` is `{ _ in }` (zero overhead).

3. **Middleware error auto-logging** — if a middleware throws, the `catch` block in `Store.buildDispatchProcess` auto-fires `context.complete(false, error: error)` before routing to the resolver chain.

4. **Resolver is non-throwing** — `Resolver.run`, `AnyResolver.run/handler`, `ResolverContext.next()` are all non-throwing. The resolver chain in `Store.swift` has no `try`.

5. **Timing** — `ContinuousClock.now` captured at build-time per step; `elapsed` computed at `complete()` time. `Duration` type throughout.

### Files modified

| File | Change |
|---|---|
| `Sources/Redux/Store/Store+Log.swift` | New — `Store.Log` enum |
| `Sources/Redux/Middleware/MiddlewareContext.swift` | Added `complete(succeeded:error:)` |
| `Sources/Redux/Reducer/ReducerContext.swift` | Added `complete(succeeded:)` + explicit internal init |
| `Sources/Redux/Resolver/ResolverContext.swift` | Added `complete(succeeded:)`, made `next()` non-throwing |
| `Sources/Redux/Resolver/Resolver.swift` | Removed `throws` from `run` |
| `Sources/Redux/Resolver/AnyResolver.swift` | Removed `throws` from handler/run |
| `Sources/Redux/Store/Store.swift` | Added `onLog` property, timing for all three pipeline stages, auto-fire on middleware throw |
| `Tests/TinyReduxTests.swift` | 10 new tests (28 total) |
