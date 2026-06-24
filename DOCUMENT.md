# TinyRedux — User Guide

|              |                                     |
|--------------|-------------------------------------|
| **Version**  | 1.0.23                              |
| **Platform** | iOS 18+, macOS 15+                  |
| **Swift**    | 6.0 (Strict Concurrency)            |

---
## Summary

**TinyRedux** is a small-footprint library, strongly inspired by ReduxJS, written in pure Swift.

## Overview

**TinyRedux** is a state-management framework for iOS and macOS applications, inspired by Redux. It centralizes application state in a single `ReduxStore` and enforces a unidirectional data flow: views dispatch actions, actions flow through a pipeline, and the resulting state updates propagate back to the UI.

The framework adopts a **Supervised Redux Model** where three components cooperate in the same pipeline with distinct responsibilities:

- **Middleware** — handles side effects (network, I/O, timers) and can transform, redirect, or defer actions.
- **Reducer** — applies pure, deterministic state transitions (the only writer).
- **Resolver** — provides structured error recovery when middleware or an effect fails.

Key capabilities:

- Native SwiftUI integration with automatic observation.
- Thread-safe dispatch from any isolation.
- **Modules & slices**: compose feature modules onto a root store (`.linear` / `.scattered`), with the feature UI depending only on `any ReduxModule<LS, LA>`.
- State→Action subscriptions registered from middleware.
- Snapshot API: `await` a JSON-encoded state projection at a pipeline terminal, or stream encoded frames.
- Opt-in per-dispatch rate control plus high-frequency backpressure diagnostics.
- Structured, typed logging that is zero-cost when no handler is attached.
- Macros that eliminate boilerplate for state and action declarations.


## Table of Contents

1. [Introduction](#1-introduction)
2. [Redux Concepts](#2-redux-concepts)
3. [Quick Start](#3-quick-start)
4. [State](#4-state)
5. [Actions](#5-actions)
6. [Reducer](#6-reducer)
7. [Middleware](#7-middleware)
8. [Resolver](#8-resolver)
9. [Store](#9-store)
10. [Subscriptions](#10-subscriptions)
11. [Snapshot API](#11-snapshot-api)
12. [Streaming Snapshots](#12-streaming-snapshots)
13. [Dispatch Pipeline](#13-dispatch-pipeline)
14. [Rate Limiting & Backpressure](#14-rate-limiting--backpressure)
15. [Logging](#15-logging)
16. [Modules & Slices](#16-modules--slices)
17. [Tutorial: A Redux Stack in a New App](#17-tutorial-a-redux-stack-in-a-new-app)
18. [Advanced Patterns](#18-advanced-patterns)
19. [Quick Reference](#19-quick-reference)

---

## 1. Introduction

TinyRedux is a Swift 6 framework for application state management based on the **Supervised Redux** model — a unidirectional data flow where middleware, reducer, and resolver cooperate within the same dispatch pipeline.

### Philosophy

- **Unidirectionality**: actions flow in a single direction through the pipeline.
- **Separation of concerns**: middleware handles side effects, reducers mutate state, resolvers handle errors.
- **Type-safe**: generic over `State` and `Action`, compiled under Strict Concurrency.
- **Observable**: `ReduxStore` is `@Observable` and `@dynamicMemberLookup`, natively integrated with SwiftUI.
- **MainActor pipeline**: the entire pipeline runs on `@MainActor`; actions are dispatched from any isolation via `nonisolated dispatch`.

### Requirements

- Swift 6.0 toolchain
- iOS 18+ / macOS 15+
- Dependency: `swift-syntax` (for the `@ReduxState`, `@ReduxMappedState`, `@ReduxAction` macros)

### Installation

Add the package to your `Package.swift`:

```swift
.package(url: "https://github.com/GiumaSoft/TinyRedux", from: "1.0.23")
```

---

## 2. Redux Concepts

### Unidirectional Flow

```
View → dispatch(action) → Middleware → Reducer → State → View
                              ↓ (error)
                           Resolver
```

| Component | Responsibility |
|---|---|
| **State** | Mutable application state, `@Observable` reference type |
| **Action** | An intent (`enum`, `Sendable`) |
| **Reducer** | Pure state mutation (synchronous, deterministic) |
| **Middleware** | Side effects (network, I/O, timers), intercepts actions pre-reducer |
| **Resolver** | Error handling from middleware/effects, non-throwing recovery |
| **Store** | Central hub: owns state and pipeline, exposes the dispatch API |

### Key Principles

1. **Single source of truth**: state is centralized in the store.
2. **Read-only state for the UI**: views observe `State.ReadOnly`; only reducers write.
3. **Actions as intent descriptors**: they carry data, not logic.
4. **Pure reducers**: no side effects; same input → same output.
5. **Middleware for side effects**: all asynchronous logic lives in middleware.

---

## 3. Quick Start

A minimal counter:

```swift
import TinyRedux

// 1. State
@ReduxState
@Observable
@MainActor
final class CounterState: ReduxState {
  var count: Int

  nonisolated convenience init() { self.init(count: 0) }
}

// 2. Action
@ReduxAction
enum CounterAction: ReduxAction {
  case increment
  case decrement
  case reset
}

// 3. Reducer
let counterReducer = AnyReduxReducer<CounterState, CounterAction>(id: "counter") { context in
  let (state, action) = context.args

  switch action {
  case .increment: state.count += 1;  return .next
  case .decrement: state.count -= 1;  return .next
  case .reset:     state.count = 0;   return .next
  }
}

// 4. Store — `reducers` is required; everything else is optional.
let store = ReduxStore(
  initialState: CounterState(),
  reducers: [counterReducer]
)

// 5. Dispatch (nonisolated — any isolation)
store.dispatch(.increment)
store.dispatch(.increment, .decrement)   // variadic
```

In SwiftUI:

```swift
import SwiftUI

struct CounterView: View {
  let store: ReduxStore<CounterState, CounterAction>

  var body: some View {
    VStack {
      Text("Counter: \(store.count)")     // via @dynamicMemberLookup
      HStack {
        Button("−") { store.dispatch(.decrement) }
        Button("Reset") { store.dispatch(.reset) }
        Button("+") { store.dispatch(.increment) }
      }
    }
  }
}
```

---

## 4. State

### ReduxState Protocol

```swift
public protocol ReduxState: AnyObject, Observable, Sendable {
  associatedtype ReadOnly: ReduxReadOnlyState where ReadOnly.State == Self
  @MainActor var readOnly: ReadOnly { get }
}
```

The state is an `@Observable` class. Mark conformers `@MainActor` to keep mutable
observable state isolated to the main actor. It exposes a `ReadOnly` projection that
middleware, resolvers, and the UI receive — only reducers write.

### ReduxReadOnlyState Protocol

```swift
public protocol ReduxReadOnlyState: AnyObject, Observable, Sendable {
  associatedtype State: ReduxState
  init(_ state: State)
}
```

A mirror class of the state that forwards each property as a get-only accessor over an
`unowned` reference to the backing state.

### @ReduxState Macro

`@ReduxState` is for an **owned, value-backed** state (a root state, or a `.linear`
module's state). The class must declare `: ReduxState` **and** `@Observable` (and
typically `@MainActor`) explicitly — a macro cannot inject those onto the type it is
attached to. The stored `var`s remain the real `@Observable` storage.

It generates:

1. The nested `ReadOnly` class with every stored `var` (excluding `@ObservationIgnored`) as a get-only accessor.
2. The `@ObservationIgnored lazy var readOnly`.
3. A designated `nonisolated init(<field>: T, …)`.

```swift
@ReduxState
@Observable
@MainActor
final class AppState: ReduxState {
  var username: String
  var isLoading: Bool
  var items: [Item]

  nonisolated convenience init() {
    self.init(username: "", isLoading: false, items: [])
  }
}
```

Generates (conceptually):

```swift
@Observable @MainActor
final class ReadOnly: ReduxReadOnlyState, Sendable {
  private unowned let state: AppState
  nonisolated init(_ state: AppState) { self.state = state }
  var username: String { state.username }
  var isLoading: Bool { state.isLoading }
  var items: [Item] { state.items }
}

@ObservationIgnored
lazy var readOnly = ReadOnly(self)

nonisolated init(username: String, isLoading: Bool, items: [Item]) {
  self._username = username
  self._isLoading = isLoading
  self._items = items
}
```

> Generated members are `public` when the annotated class is `public`/`open`, so a
> `public` state type compiles its public-protocol conformance and is usable from another
> module (e.g. an external feature framework).

### SwiftUI Integration

`ReduxStore` is `@Observable` and `@dynamicMemberLookup`: views read state via key paths
straight on the store.

```swift
struct MyView: View {
  let store: ReduxStore<AppState, AppAction>

  var body: some View {
    Text(store.username)                 // via dynamicMemberLookup
    if store.isLoading { ProgressView() }
  }
}
```

---

## 5. Actions

### ReduxAction Protocol

```swift
public protocol ReduxAction: CustomStringConvertible,
                             CustomDebugStringConvertible,
                             Identifiable, Equatable, Sendable {
  var id: String { get }
}
```

Actions are `Sendable` enums that cross the `nonisolated → @MainActor` boundary.

- `id`: identifies the case (used for logging and rate limiting).
- `description` / `debugDescription`: default to `id` (from the protocol extension).
- `Equatable`: identity is **case-only** by default — associated values are ignored. Override `==` for payload-sensitive equality.

### @ReduxAction Macro

`@ReduxAction` synthesizes `id` from the case names:

```swift
@ReduxAction
enum AppAction: ReduxAction {
  case login(username: String, password: String)
  case logout
  case setProfile(Profile)
}
```

Generates:

```swift
public var id: String {
  switch self {
  case .login:      return "login"
  case .logout:     return "logout"
  case .setProfile: return "setProfile"
  }
}
```

### Richer logging

To expose associated values in logs, override `description`/`debugDescription`:

```swift
extension AppAction {
  var debugDescription: String {
    switch self {
    case .login(let username, _): "login(username: \(username))"
    case .setProfile(let p):      "setProfile(\(p.name))"
    default:                      description
    }
  }
}
```

---

## 6. Reducer

### ReduxReducer Protocol

```swift
public protocol ReduxReducer: Identifiable, Sendable {
  associatedtype S: ReduxState
  associatedtype A: ReduxAction
  var id: String { get }
  var reduce: ReduxReduceHandler<S, A> { get }
}
```

The reducer is the **only component** allowed to mutate state. It must be:

- **Pure**: no side effects, no network calls, no I/O.
- **Deterministic**: same input → same output.
- **Synchronous**: simple assignments. Complex/async logic belongs in middleware.

### ReduxReducerContext

```swift
public struct ReduxReducerContext<S, A>: Sendable {
  public let state: S       // mutable state (the reducer writes it)
  public let action: A
  public var args: (S, A)   // destructuring convenience
}
```

### ReduxReducerExit

```swift
public enum ReduxReducerExit: Sendable {
  case next         // handled — state mutated, continue to next reducers
  case done         // handled — state mutated, skip remaining reducers
  case defaultNext  // not handled — no state change, continue
}
```

| Case | State Mutated | Logged | Subsequent Reducers |
|---|---|---|---|
| `.next` | Yes | Yes | Run |
| `.done` | Yes | Yes | Skipped |
| `.defaultNext` | No | Yes¹ | Run |

¹ Reducers log every exit (the worker wraps `reduce` in `measuring`). Middleware and resolver, by contrast, skip logging `.defaultNext`.

### AnyReduxReducer

Type-erased reducer. Several ways to build it:

```swift
// 1. From a closure
let reducer = AnyReduxReducer<AppState, AppAction>(id: "main") { context in
  let (state, action) = context.args
  switch action {
  case .setProfile(let p): state.profile = p; return .next
  default:                 return .defaultNext
  }
}

// 2. From a conformer
let wrapped = AnyReduxReducer(MyReducer())

// 3. Lift a local reducer into the root space (linear)
let lifted = AnyReduxReducer(authReducer, toState: { $0.auth }, toAction: \.authAction)

// 4. Lift via a ReduxModuleMap (linear or scattered — see Section 16)
let module = AnyReduxReducer(featureReducer, moduleMap: featureMap)
```

### Rules

1. Use `.defaultNext` for actions a reducer does not handle.
2. Use `.done` only to stop subsequent reducers.
3. Reducers run in **declaration order** (forward).
4. After the reducers run, subscriptions and snapshot streams are evaluated.

---

## 7. Middleware

### Middleware Protocol

```swift
public protocol Middleware<S, A>: Identifiable, Sendable {
  associatedtype S: ReduxState
  associatedtype A: ReduxAction
  var id: String { get }
  @MainActor func run(_ context: MiddlewareContext<S, A>) throws -> MiddlewareExit<S, A>
}
```

Middleware intercepts actions **before** the reducers. It is the place for network calls,
I/O, timers, validation, action transformation, and subscription registration. A `throw`
is routed to the resolver.

### MiddlewareContext

```swift
public struct MiddlewareContext<S, A>: Sendable {
  public let state: S                      // live state — READ-ONLY by convention
  public let dispatch: @Sendable (A) -> Void
  public let action: A
  // + subscribe(id:when:then:) / unsubscribe(id:)
}
```

> The middleware receives the **live** state but must only read it — the reducer is the
> sole writer. Effect bodies (`.task` / `.deferred`) receive the `S.ReadOnly` projection.

### MiddlewareExit

```swift
public enum MiddlewareExit<S, A>: Sendable {
  case next                          // continue the chain (handled). Logged.
  case defaultNext                   // continue, "not mine". NOT logged.
  case nextAs(A)                     // continue with a DIFFERENT action. Logged.
  case exit(MiddlewareExitTarget<A>) // leave the chain. Logged.
  case task(TaskHandler<S>)          // fire-and-forget async effect; chain continues
  case deferred(DeferredTaskHandler<S, A>) // suspend the chain, resume on completion
}

public enum MiddlewareExitTarget<A>: Sendable {
  case reduce            // → reducer with the current action (skip remaining middleware)
  case reduceAs(A)       // → reducer with a DIFFERENT action
  case resolve(SendableError) // → resolver (explicit, manually-caught error routing)
  case done              // → terminate, NO reduce (success)
}
```

| Exit | Chain | Reducer | Notes |
|---|---|---|---|
| `.next` | continues | yes (at the seed) | handled |
| `.defaultNext` | continues | yes (at the seed) | pass-through, not logged |
| `.nextAs(a)` | continues with `a` | yes | transformed |
| `.exit(.reduce)` | leaves | yes (current action) | short-circuit to reducer |
| `.exit(.reduceAs(a))` | leaves | yes (`a`) | short-circuit to reducer |
| `.exit(.resolve(e))` | leaves | — | route to resolver |
| `.exit(.done)` | leaves | no | fully handled |
| `.task(body)` | continues | yes | effect runs alongside |
| `.deferred(handler)` | suspends | depends on resume | async then resume |
| `throw` | leaves | — | routed to resolver |

### .task — Fire-and-Forget

Launches an async effect; the chain continues immediately. The body runs on the main actor
(reads `@MainActor` state; `await` points free the main actor for I/O). Any `throw` is
routed to the resolver.

```swift
return .task { state in
  try await api.sendAnalytics(event: state.lastEvent)
}
```

### .deferred — Suspended Pipeline

Suspends the chain awaiting the async result. The handler receives `S.ReadOnly` and returns
a `MiddlewareResumeExit`:

```swift
return .deferred { state in
  let user = try await api.fetchUser(id: state.userId)
  return .nextAs(.setUser(user))
}
```

```swift
public enum MiddlewareResumeExit<A>: Sendable {
  case next                          // resume with the original action
  case nextAs(A)                     // resume with a different action
  case exit(MiddlewareExitTarget<A>) // reduce / reduceAs / resolve / done
}
```

> **Ordering caveat.** A `.deferred` effect runs on a child task; subsequent queued actions
> can be processed before it resumes. If the resumed work must be ordered relative to later
> actions, end the deferred body by `dispatch`ing a follow-up action (a fresh FIFO entry)
> rather than resuming straight into the reduce chain.

### AnyMiddleware

```swift
// From a closure
let logger = AnyMiddleware<AppState, AppAction>(id: "logger") { context in
  print("Action: \(context.action)")
  return .defaultNext
}

// From a conformer
let wrapped = AnyMiddleware(MyMiddleware())

// Lift a local middleware via a ReduxModuleMap (Section 16)
let module = AnyMiddleware(featureMiddleware, moduleMap: featureMap)
```

### Execution Order

The **first middleware in the array receives the action first**.

```swift
ReduxStore(
  initialState: state,
  reducers: [reducer],
  middlewares: [middlewareA, middlewareB, middlewareC]  // A runs first
)
```

Flow: `A → B → C → reducer`.

### subscribe / unsubscribe

Middleware registers State→Action subscriptions through the context:

```swift
context.subscribe(id: "waitForLogin", when: { $0.isLoggedIn }) { .fetchProfile }
context.unsubscribe(id: "waitForLogin")
```

See [Section 10](#10-subscriptions).

---

## 8. Resolver

### Resolver Protocol

```swift
public protocol Resolver<S, A>: Identifiable, Sendable {
  associatedtype S: ReduxState
  associatedtype A: ReduxAction
  var id: String { get }
  @MainActor func run(_ context: ResolverContext<S, A>) -> ResolverExit<A>
}
```

The resolver is the error branch. It handles errors raised by a middleware `throw`, an
explicit `.exit(.resolve(_))`, or a failing effect. It **cannot throw** — every recovery is
expressed via `ResolverExit`.

### ResolverContext

```swift
public struct ResolverContext<S, A>: Sendable {
  public let state: S                  // live state — read-only by convention
  public let action: A                 // the action that errored
  public let error: SendableError
  public let origin: ReduxOrigin       // id of the middleware that raised the error
  public let dispatch: @Sendable (A) -> Void
}
```

### ResolverExit

```swift
public enum ResolverExit<A>: Sendable {
  case defaultNext                    // not mine → next resolver (default → fail). NOT logged.
  case exit(ResolverExitTarget<A>)    // leave the chain. Logged.
}

public enum ResolverExitTarget<A>: Sendable {
  case reduce             // → reducer with the original (erroring) action — recovered
  case reduceAs(A)        // → reducer with a recovery action
  case fail(SendableError)// → terminate as FAILED (the error is final)
  case done               // → terminate as success (error absorbed, no state change)
}
```

| Exit | Reducer | Outcome |
|---|---|---|
| `.defaultNext` | — | pass to next resolver |
| `.exit(.reduce)` | yes (current action) | recovered → reduce |
| `.exit(.reduceAs(a))` | yes (`a`) | recovered → reduce |
| `.exit(.done)` | no | error absorbed (success) |
| `.exit(.fail(e))` | no | terminal failure |

### Automatic Default (Seed)

If no resolver handles the error (all return `.defaultNext`), the framework logs a
`resolver` event with id `"default"` and `.exit(.fail(error))`, and fails any pending
single-shot snapshot. No developer-side "default resolver" is required.

### AnyResolver

```swift
let errorResolver = AnyResolver<AppState, AppAction>(id: "error") { context in
  if context.error is NetworkError {
    context.dispatch(.showError(context.error))
    return .exit(.done)
  }
  return .defaultNext
}

// Lift a local resolver via a ReduxModuleMap (Section 16)
let module = AnyResolver(featureResolver, moduleMap: featureMap)
```

### Execution Order

Like middleware, the **first resolver in the array runs first**.

---

## 9. Store

### Definition & Initialization

```swift
@Observable
@dynamicMemberLookup
public final class ReduxStore<S, A>: ReduxModule, Sendable
where S: ReduxState, A: ReduxAction
```

```swift
let store = ReduxStore(
  initialState: AppState(),
  reducers: [reducer1, reducer2],            // required
  middlewares: [middleware1, middleware2],   // default []
  resolvers: [resolver1],                    // default []
  options: StoreOptions(),                   // default
  onLog: { event in print(event) }           // default nil
)
```

The store creates the `Worker` internally and starts its event loop. There is no
`start()` — the pipeline is live immediately.

### Lifecycle

- **init**: builds the worker, dispatcher, and the main-actor event-loop task.
- **deinit**: finishes the dispatcher stream (ending the loop) and eagerly finishes every active snapshot stream (via a main-actor hop) so consumers' `for await` loops end.

### Dispatch API

```swift
// Fire-and-forget (variadic) — nonisolated, any isolation
store.dispatch(.increment)
store.dispatch(.increment, .increment, .decrement)

// With an opt-in rate limit (Section 14)
store.dispatch(.cameraFrame(buffer), rate: .throttle(.milliseconds(33)))

// Async single-shot snapshot (Section 11)
let result = await store.dispatch(.saveProfile, snapshot: ProfileSnapshot.self)

// Snapshot stream (Section 12)
let frames = store.dispatch(.startFeed, snapshot: SnapshotSpec(...))
```

### State Access

```swift
let name = store.username       // via dynamicMemberLookup — @MainActor
let state = store.state         // S.ReadOnly — @MainActor
let name2 = state.username
```

### SwiftUI Binding

Every `ReduxModule` (including `ReduxStore`) provides a two-way `bind`: it reads via
`state` and writes via `dispatch(embed(_:))`.

```swift
let binding = store.bind(\.searchText, to: { .setSearchText($0) })
// In SwiftUI: TextField("Search", text: binding)
```

### Preview State

```swift
// ⛔️ DO NOT USE IN PRODUCTION — mutates live state, bypassing the pipeline.
// For SwiftUI previews only.
store.previewState { state in
  state.username = "Preview User"
  state.isLoading = false
}
```

`previewState` is `@discardableResult` and returns the store, so it chains into a preview.

---

## 10. Subscriptions

Subscriptions are **State→Action reactions** registered by middleware: when `when(state)`
holds after a reduce, the worker dispatches `then(state)`.

### Registration

```swift
// reaction reads the state
context.subscribe(id: "waitForAuth",
                  when: { $0.isAuthenticated },
                  then: { state in .loadDashboard(userId: state.userId) })

// reaction ignores the state
context.subscribe(id: "waitForAuth",
                  when: { $0.isAuthenticated },
                  then: { .loadDashboard })
```

`subscribe` returns the id (auto-`UUID` if omitted).

### Semantics

- **Post-reducer**: every subscription is re-evaluated after each reduce terminal.
- **Not one-shot**: a subscription fires every time its predicate holds. Its lifecycle is yours — call `unsubscribe(id:)` to remove it.
- **Keyed by id**: registering with the same id replaces the previous entry.

### Unsubscribe

```swift
context.unsubscribe(id: "waitForAuth")
```

### Evaluation Flow

```
reducers run
    ↓
evaluateSubscriptions()
    ↓
for each subscription where when(readOnly) == true:
    dispatch(then(readOnly))   // new pipeline entry
```

---

## 11. Snapshot API

The single-shot snapshot API `await`s a JSON-encoded projection of the state captured at
the action's pipeline terminal.

### ReduxStateSnapshot Protocol

```swift
public protocol ReduxStateSnapshot<S>: Codable, Sendable {
  associatedtype S: ReduxState
  @MainActor init(state: S.ReadOnly)
}
```

### Defining a Snapshot

```swift
struct ProfileSnapshot: ReduxStateSnapshot {
  typealias S = AppState
  let username: String
  let email: String

  @MainActor init(state: AppState.ReadOnly) {
    self.username = state.username
    self.email = state.email
  }
}
```

### Usage

```swift
let result = await store.dispatch(.updateProfile(name: "Alice"), snapshot: ProfileSnapshot.self)

switch result {                               // ReduxEncodedSnapshot = Result<Data, Error>
case .success(let data):
  let snapshot = try JSONDecoder().decode(ProfileSnapshot.self, from: data)
  print(snapshot.username)
case .failure(let error):
  // pipeline error, ReduxError.rateLimited, ReduxError.terminated / .cancelled, or encode error
}
```

### Semantics

- The action goes through the same FIFO queue as `dispatch(_:)` (always `.none` rate — a request/response is never rate-limited).
- The caller suspends until the action reaches its terminal — the end of the reducer chain, or any non-reducing exit (`.exit(.done)`, a resolver outcome).
- The snapshot is built and JSON-encoded on the main actor with the worker's shared encoder.
- If the pipeline fails (unhandled error / resolver `.fail`), the result is `.failure`. If the store is torn down before the action settles, it is `.failure(ReduxError.cancelled)`.

---

## 12. Streaming Snapshots

The streaming overload returns a **bounded** `AsyncStream` of encoded snapshots, emitted
whenever an edge-trigger key changes at a reduce terminal. `snapshot: Type.self` returns
**one** value; `snapshot: SnapshotSpec(…)` returns a **stream**.

```swift
let stream = store.dispatch(.startFeed, snapshot: SnapshotSpec(
  ReadingSnapshot.self,
  changeOn: { $0.sample.version },           // edge-trigger key
  emitInitial: false,
  limit: .timeOrCount(.seconds(30), 100)
))

for await frame in stream {                  // each frame is Result<Data, Error>
  if case .success(let data) = frame { /* … */ }
}
```

### SnapshotSpec

```swift
public struct SnapshotSpec<S>: Sendable {
  public enum Limit: Sendable {
    case count(UInt)                 // ends after the first N successfully-encoded frames
    case time(Duration)              // ends when the time window elapses
    case timeOrCount(Duration, UInt) // ends at whichever is reached first
  }
}
```

- **`changeOn`** — a frame is emitted only when the key changes (state changes only at a reduce terminal). Choose a key that tracks what the snapshot captures.
- **`emitInitial`** — emit the current state at registration (default `false`). Closes the gap when the arming action itself causes the change.
- **`limit`** — **required**; every stream is finite. A zero count bound is rejected in debug and finishes immediately in release.
- A second initializer takes a `build:` closure when the snapshot needs call-site context beyond the state.

### Lifecycle

The entry is registered **before** the arming action is enqueued (same main-actor turn), so
a change caused by the arming action is not missed. The stream ends at the `limit`, on
consumer cancellation (breaking the `for await` loop), if the arming action is rejected at
the gate, and eagerly on store `deinit`. The buffer is unbounded: a slow consumer receives
every frame in order. A frame that fails to encode is delivered as `.failure` and does
**not** count toward a `.count` bound — one bad reading must not kill a live feed.

---

## 13. Dispatch Pipeline

```
dispatch(action)                       [nonisolated — any isolation]
    │
    ▼
Dispatcher.tryEnqueue(rate)            [rate gate; .none is lock-free]
    │   .limit / .throttle may drop → ReduxError.rateLimited (logged)
    ▼
AsyncStream(.unbounded)                [FIFO transport]
    │
    ▼
Worker loop [MainActor] — for await event in events
    │   trackPressure(action.id)       [high-frequency diagnostics]
    │
    ▼
runMiddleware(action, terminal)        [fold, declaration order]
    │
    ├── .next / .defaultNext      → next middleware
    ├── .nextAs(a)                → next middleware with a
    ├── .exit(.reduce/.reduceAs)  → reduceChain
    ├── .exit(.resolve(e)) / throw→ resolveChain
    ├── .exit(.done)              → terminal(.success(state))
    ├── .task(body)               → runTask (fire-and-forget) + continue
    └── .deferred(handler)        → runDeferredTask (suspend, resume)
    │
    ▼  (seed of the middleware fold)
reduceChain(action, terminal)
    │   runReducers(action)            [forward; .done stops early]
    │   evaluateSubscriptions()        [State→Action]
    │   evaluateStreams()              [snapshot streams tick]
    │   terminal?(.success(state.readOnly))
    ▼
dispatcher.consume(id:counted:)        [release a .limit slot if counted]
```

### Resolver Chain (on error)

```
resolveChain(error, action, origin, terminal)
    │   fold over resolvers (declaration order); seed = fail
    │
    ├── .defaultNext             → next resolver
    └── .exit(...)               → .reduce / .reduceAs → reduceChain
                                   .done               → terminal(.success(state))
                                   .fail(e)            → terminal(.failure(e))
    │
    └── seed (unhandled): log resolver "default" .fail(error); terminal(.failure(error))
```

---

## 14. Rate Limiting & Backpressure

The dispatcher buffer is **unbounded** — logical actions are never silently dropped, so the
action log stays deterministic and replayable. Two distinct mechanisms manage load:

### DispatchRateLimit (opt-in, per dispatch)

```swift
public enum DispatchRateLimit: Sendable {
  case none                 // default: always enqueued, never dropped
  case limit(Int)           // at most N actions with the same id pending (un-reduced)
  case throttle(Duration)   // at most one per id per window (leading edge)
}
```

For high-frequency **sample-stream** actions (AR frames, sensors), opt in per dispatch:

```swift
store.dispatch(.sensorReading(value), rate: .throttle(.milliseconds(20)))
store.dispatch(.cameraFrame(buffer),  rate: .limit(2))
```

A drop produces `ReduxError.rateLimited`, which is logged (`.store("discarded action …")`).
`.none` is lock-free; `.limit`/`.throttle` gate admission under a small mutex.

### Backpressure Diagnostics

Configured via `StoreOptions`, this is a pure **warning** (no drop). When the same
`action.id` exceeds the threshold within the window, the worker emits
`.highFrequencyAction`:

```swift
public struct StoreOptions: Sendable {
  public var pressureWindow: Duration     // default .seconds(1)
  public var pressureThreshold: Int       // default 120
  public var pressureCooldown: Duration   // default .seconds(5) — anti-spam
}
```

Defaults are tuned above UI frequency, so the warning fires only on genuine floods. The
detector only runs when a log handler is attached.

### ReduxError

```swift
public enum ReduxError: Error, Sendable {
  case terminated   // the dispatcher stream is shutting down
  case rateLimited  // a DispatchRateLimit dropped this action at the gate
  case cancelled    // a pending snapshot was abandoned because the store was torn down
}
```

---

## 15. Logging

Logging is a typed, structured event stream. Construction is lazy: nothing is built (and no
clock is read) when no handler is attached.

```swift
public enum ReduxLog<S, A>: Sendable {
  case reducer(id: String, action: A, duration: Duration, exit: ReduxReducerExit)
  case middleware(id: String, action: A, duration: Duration, exit: MiddlewareExit<S, A>)
  case resolver(id: String, action: A, duration: Duration, exit: ResolverExit<A>, error: SendableError)
  case subscription(SubscriptionLog<A>)
  case snapshot(SnapshotLog<A>)
  case highFrequencyAction(id: String, count: Int, window: Duration)
  case store(String)
}

public typealias ReduxLogHandler<S, A> = @Sendable (ReduxLog<S, A>) -> Void
```

`SubscriptionLog` carries `.subscribed` / `.executed` / `.unsubscribed`; `SnapshotLog`
covers single-shot `.resolved` / `.failed` and stream
`.streamRegistered` / `.streamFrame` / `.streamEncodeFailed` / `.streamFinished`.

### What is and isn't logged

- `.defaultNext` from **middleware** or **resolver** is not logged (pass-through). Reducers log every exit.
- Timing is measured automatically (only when a handler exists).

### Handler

The handler is `@Sendable` and owns its own thread-safety — e.g. wrap an `os.Logger`,
which is already thread-safe:

```swift
import OSLog

enum AppLog {
  static let logger = Logger(subsystem: "com.example.app", category: "redux")

  @Sendable
  static func handle(_ event: ReduxLog<AppState, AppAction>) {
    switch event {
    case let .reducer(id, action, duration, exit):
      logger.log("↩️ reducer[\(id)] · \(action.id) · \(duration) · \(String(describing: exit))")
    case let .middleware(id, action, duration, exit):
      logger.log("⚙️ middleware[\(id)] · \(action.id) · \(duration) · \(String(describing: exit))")
    case let .resolver(id, action, duration, exit, error):
      logger.log("🛟 resolver[\(id)] · \(action.id) · \(duration) · \(String(describing: exit)) · \(error)")
    case let .subscription(e): logger.log("🔔 \(String(describing: e))")
    case let .snapshot(e):     logger.log("📸 \(String(describing: e))")
    case let .highFrequencyAction(id, count, window):
      logger.log("⚠️ high-frequency · \(id) · \(count)× in \(window)")
    case let .store(message):  logger.log("🏬 \(message)")
    }
  }
}

let store = ReduxStore(initialState: AppState(), reducers: [reducer], onLog: AppLog.handle)
```

---

## 16. Modules & Slices

A **module** is a self-contained feature (its own state, actions, reducer, and UI) that
imports only `TinyRedux` and never the host app. A **`ReduxModuleMap`** plugs the module's
local `LS`/`LA` into a central store's `S`/`A`. The **same map** drives both the reducer
lift and the View's slice — so the projection and extraction are written once.

```swift
public struct ReduxModuleMap<LS, LA, S, A>: Sendable { … }
```

| Function | Role |
|---|---|
| `toState: (S) -> LS` | project the global state onto the local state (read + reduce) |
| `toAction: (A) -> LA?` | extract the local action from a global one (`nil` = not mine) |
| `toRootAction: (LA) -> A` | lift a local action back into the global space (dispatch path) |

### ReduxModule (the UI-facing facade)

A feature View depends only on the existential `any ReduxModule<LS, LA>`:

```swift
@MainActor
public protocol ReduxModule<S, A>: Sendable {
  associatedtype S: ReduxState
  associatedtype A: ReduxAction
  var state: S.ReadOnly { get }
  nonisolated func dispatch(_ actions: A...)
  func bind<Value>(_ keyPath: KeyPath<S.ReadOnly, Value>,
                   to embed: @escaping @Sendable (Value) -> A) -> Binding<Value>
}
```

Both `ReduxStore` (standalone) and `ReduxStoreSlice` (scoped) conform. The View doesn't
know whether it talks to the root store or a slice, nor whether the mapping is `.linear` or
`.scattered`.

```swift
public struct CounterFeatureView: View {
  let module: any ReduxModule<CounterFeatureState, CounterFeatureActions>
  public var body: some View {
    HStack {
      Button("−") { module.dispatch(.decrement) }
      Text("\(module.state.count)")
      Button("+") { module.dispatch(.increment) }
    }
  }
}
```

### Linear composition

`LS` is a contiguous sub-object of `S`, and `LA` a single case of `A`. Use `@ReduxState`
for the module state (it owns its storage) and nest it in the root state.

```swift
@ReduxState @Observable @MainActor
final class AppState: ReduxState {
  var counter: Int
  var auth: AuthModuleState               // nested owned module state
  nonisolated convenience init() { self.init(counter: 0, auth: AuthModuleState()) }
}

extension AppActions {
  var authModule: AuthModuleActions? {
    guard case let .authModule(a) = self else { return nil }
    return a
  }
}

let map = ReduxModuleMap<AuthModuleState, AuthModuleActions, AppState, AppActions>
  .linear(state: \.auth, action: \.authModule, toRootAction: AppActions.authModule)

let store = ReduxStore(
  initialState: AppState(),
  reducers: [
    mainReducer,
    AnyReduxReducer(authReducer, moduleMap: map)
    // or, without a map: AnyReduxReducer(authReducer, toState: { $0.auth }, toAction: \.authModule)
  ]
)
```

### Scattered composition

The module state is a **`@ReduxMappedState`** — it owns no storage; each field is projected
field-by-field via a `ReduxBinding` onto whatever the app owns. The module stays ignorant of
`AppState`.

```swift
// In the feature framework:
@ReduxMappedState @MainActor
public final class CounterFeatureState: ReduxMappedState {
  public var count: Int                   // forwards through a ReduxBinding
}

// In the app — the composition root:
let counterMap = ReduxModuleMap<CounterFeatureState, CounterFeatureActions, AppState, AppActions>
  .scattered(
    state: { app in
      CounterFeatureState(count: ReduxBinding { app.counter } set: { app.counter = $0 })
    },
    action: \.counter,
    toRootAction: AppActions.counter
  )

let store = ReduxStore(
  initialState: AppState(),
  reducers: [AnyReduxReducer(counterFeatureReducer, moduleMap: counterMap)]
)

// In a View:
CounterFeatureView(module: store.slice(counterMap))
```

`@ReduxMappedState` requires `: ReduxMappedState` and `@MainActor` — **do not** add
`@Observable` (the fields become computed forwarders; observability rides the binding
target). `ReduxBinding.constant(_:)` and `.projected(_:)` back previews and tests without a
root.

### slice(_:)

`ReduxStore.slice(_:)` vends a scoped `ReduxStoreSlice` from a map (or from an explicit
projection + `toRootAction`, or a `KeyPath` for the linear case). The local state is
projected **once** and retained by the slice, so a mapped state's `unowned` `ReadOnly`
cannot dangle; reads still observe the live root because the projection forwards to the root
leaves.

---

## 17. Tutorial: A Redux Stack in a New App

A small "Todo" stack.

### Step 1 — State

```swift
import TinyRedux

@ReduxState @Observable @MainActor
final class TodoState: ReduxState {
  var items: [TodoItem]
  var isLoading: Bool
  var error: String?

  nonisolated convenience init() { self.init(items: [], isLoading: false, error: nil) }
}

struct TodoItem: Identifiable, Codable, Sendable {
  let id: UUID
  var title: String
  var isCompleted: Bool
}
```

### Step 2 — Actions

```swift
@ReduxAction
enum TodoAction: ReduxAction {
  case addTodo(String)
  case toggleTodo(UUID)
  case fetchTodos
  case setTodos([TodoItem])
  case setLoading(Bool)
  case setError(String?)
}
```

### Step 3 — Reducer

```swift
let todoReducer = AnyReduxReducer<TodoState, TodoAction>(id: "todo") { context in
  let (state, action) = context.args
  switch action {
  case .addTodo(let title):
    state.items.append(TodoItem(id: UUID(), title: title, isCompleted: false)); return .next
  case .toggleTodo(let id):
    guard let i = state.items.firstIndex(where: { $0.id == id }) else { return .defaultNext }
    state.items[i].isCompleted.toggle(); return .next
  case .setTodos(let items):  state.items = items;   return .next
  case .setLoading(let v):    state.isLoading = v;   return .next
  case .setError(let e):      state.error = e;       return .next
  default:                    return .defaultNext
  }
}
```

### Step 4 — Middleware

```swift
let todoMiddleware = AnyMiddleware<TodoState, TodoAction>(id: "todoAPI") { context in
  switch context.action {
  case .fetchTodos:
    context.dispatch(.setLoading(true))
    return .deferred { _ in
      let todos = try await TodoAPI.fetchAll()
      return .nextAs(.setTodos(todos))
    }
  case .setTodos:
    context.dispatch(.setLoading(false), .setError(nil))   // ⚠ see note
    return .next
  default:
    return .defaultNext
  }
}
```

> `context.dispatch` takes a single action; for several, call it more than once or use
> `.nextAs`. (The store's own `dispatch` is variadic.)

### Step 5 — Resolver

```swift
let todoResolver = AnyResolver<TodoState, TodoAction>(id: "todoError") { context in
  if context.error is URLError {
    context.dispatch(.setLoading(false))
    context.dispatch(.setError("Network error: \(context.error.localizedDescription)"))
    return .exit(.done)
  }
  return .defaultNext
}
```

### Step 6 — Store

```swift
extension ReduxStore where S == TodoState, A == TodoAction {
  static let todo = ReduxStore(
    initialState: TodoState(),
    reducers: [todoReducer],
    middlewares: [todoMiddleware],
    resolvers: [todoResolver]
  )
}
```

### Step 7 — View

```swift
import SwiftUI

struct TodoListView: View {
  let store = ReduxStore.todo

  var body: some View {
    NavigationStack {
      Group {
        if store.isLoading { ProgressView() }
        else {
          List(store.state.items) { item in
            HStack {
              Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                .onTapGesture { store.dispatch(.toggleTodo(item.id)) }
              Text(item.title).strikethrough(item.isCompleted)
            }
          }
        }
      }
      .navigationTitle("Todo")
      .onAppear { store.dispatch(.fetchTodos) }
    }
  }
}
```

---

## 18. Advanced Patterns

### 18.1 Caching with `.exit(.done)`

```swift
case .fetchProfile:
  if context.state.profileCacheValid { return .exit(.done) }  // no reducer, no fetch
  return .defaultNext
```

### 18.2 Resolver recovery into the reducer

```swift
let retryResolver = AnyResolver<AppState, AppAction>(id: "retry") { context in
  if context.error is TimeoutError, context.state.retryCount < 3 {
    context.dispatch(.incrementRetry)
    return .exit(.reduceAs(.setLoading(true)))   // bypass middleware, straight to reducer
  }
  return .defaultNext
}
```

### 18.3 Auth guard via explicit resolve

```swift
let authGuard = AnyMiddleware<AppState, AppAction>(id: "authGuard") { context in
  guard context.state.token != nil else { return .exit(.resolve(AuthError.notAuthenticated)) }
  return .defaultNext
}

let authResolver = AnyResolver<AppState, AppAction>(id: "authRecover") { context in
  if context.error is AuthError { context.dispatch(.showLoginScreen); return .exit(.done) }
  return .defaultNext
}
```

### 18.4 Reactive side effects via subscriptions

```swift
case .appLaunched:
  context.subscribe(id: "firstLoginComplete",
                    when: { $0.isLoggedIn && $0.profileLoaded },
                    then: { .completeOnboarding })
  return .next
```

### 18.5 `.exit(.reduce)` vs `.exit(.done)`

- `.exit(.reduce)` / `.exit(.reduceAs(_))` — leave the middleware chain but still run the reducer.
- `.exit(.done)` — fully handled by the middleware; the pipeline terminates without a reduce.

---

## 19. Quick Reference

### Protocols

| Protocol | Constraints | Role |
|---|---|---|
| `ReduxState` | `AnyObject, Observable, Sendable` | Mutable state |
| `ReduxReadOnlyState` | `AnyObject, Observable, Sendable` | Read-only projection |
| `ReduxMappedState` | `: ReduxState` | Field-projected (scattered) module state |
| `ReduxAction` | `CustomStringConvertible, CustomDebugStringConvertible, Identifiable, Equatable, Sendable` | Dispatchable action |
| `ReduxStateSnapshot` | `Codable, Sendable` | Encodable state projection |
| `ReduxModule` | `@MainActor, Sendable` | UI-facing facade (store or slice) |
| `Middleware` | `Identifiable, Sendable` | Side effects |
| `ReduxReducer` | `Identifiable, Sendable` | State mutation |
| `Resolver` | `Identifiable, Sendable` | Error recovery |

### Value & reference types

| Type | Role |
|---|---|
| `ReduxStore<S, A>` | The store (a standalone `ReduxModule`) |
| `ReduxStoreSlice<LS, LA>` | A scoped module vended by `slice(_:)` |
| `ReduxModuleMap<LS, LA, S, A>` | Composition descriptor (`.linear` / `.scattered`) |
| `ReduxBinding<V>` | Sendable get/set projection backing a mapped state |
| `AnyMiddleware<S, A>` / `AnyReduxReducer<S, A>` / `AnyResolver<S, A>` | Type-erasure + lifts |
| `MiddlewareContext` / `ReduxReducerContext` / `ResolverContext` | Component contexts |
| `SnapshotSpec<S>` | Snapshot stream specification |
| `StoreOptions` | Backpressure-diagnostics configuration |

### Enums

| Enum | Cases |
|---|---|
| `MiddlewareExit<S, A>` | `.next, .defaultNext, .nextAs, .exit, .task, .deferred` |
| `MiddlewareExitTarget<A>` | `.reduce, .reduceAs, .resolve, .done` |
| `MiddlewareResumeExit<A>` | `.next, .nextAs, .exit` |
| `ReduxReducerExit` | `.next, .done, .defaultNext` |
| `ResolverExit<A>` | `.defaultNext, .exit` |
| `ResolverExitTarget<A>` | `.reduce, .reduceAs, .fail, .done` |
| `DispatchRateLimit` | `.none, .limit, .throttle` |
| `ReduxError` | `.terminated, .rateLimited, .cancelled` |
| `ReduxLog<S, A>` | `.reducer, .middleware, .resolver, .subscription, .snapshot, .highFrequencyAction, .store` |

### Public type aliases

| Alias | Signature |
|---|---|
| `SendableError` | `any Error & Sendable` |
| `ReduxOrigin` | `String` |
| `ReduxEncodedSnapshot` | `Result<Data, Error>` |
| `ReduxLogHandler<S, A>` | `@Sendable (ReduxLog<S, A>) -> Void` |
| `MiddlewareHandler<S, A>` | `@MainActor (MiddlewareContext<S, A>) throws -> MiddlewareExit<S, A>` |
| `ReduxReduceHandler<S, A>` | `@MainActor (ReduxReducerContext<S, A>) -> ReduxReducerExit` |
| `ResolveHandler<S, A>` | `@MainActor (ResolverContext<S, A>) -> ResolverExit<A>` |
| `TaskHandler<S>` | `@MainActor @Sendable (S.ReadOnly) async throws -> Void` |
| `DeferredTaskHandler<S, A>` | `@MainActor @Sendable (S.ReadOnly) async throws -> MiddlewareResumeExit<A>` |
| `SubscriptionPredicate<S>` | `@MainActor @Sendable (S.ReadOnly) -> Bool` |
| `SubscriptionHandler<S, A>` | `@MainActor @Sendable (S.ReadOnly) -> A` |

### Macros

| Macro | Target | Generates |
|---|---|---|
| `@ReduxState` | `class` (owned state) | `ReadOnly`, `readOnly`, designated `init(<field>: T, …)` |
| `@ReduxMappedState` | `class` (scattered state) | `ReadOnly`, `readOnly`, `init(<field>: ReduxBinding<T>, …)`, binding-backed fields, `Observable` marker |
| `@ReduxAction` | `enum` | `var id: String` from case names |

### Store API

| Member | Isolation | Returns |
|---|---|---|
| `dispatch(_:)` (variadic) | `nonisolated` | `Void` |
| `dispatch(_:rate:)` | `nonisolated` | `Void` |
| `dispatch(_:snapshot: T.Type)` | `nonisolated async` | `ReduxEncodedSnapshot` |
| `dispatch(_:snapshot: SnapshotSpec<S>)` | `nonisolated` | `AsyncStream<ReduxEncodedSnapshot>` |
| `slice(_:)` | `@MainActor` | `ReduxStoreSlice<LS, LA>` |
| `state` | `@MainActor` | `S.ReadOnly` |
| `bind(_:to:)` | `@MainActor` | `Binding<Value>` |
| `previewState(_:)` | `@MainActor` | `Self` (⛔️ not for production) |
| `subscript(dynamicMember:)` | `@MainActor` | `Value` |
