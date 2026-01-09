# TinyRedux — User Guide

|              |                                     |
|--------------|-------------------------------------|
| **Version**  | 14.1.0                              |
| **Platform** | iOS 18+, macOS 15+                  |
| **Swift**    | 6.0 (Strict Concurrency)            |

---
## Summary

**TinyRedux** is a small-footprint library, strongly inspired by ReduxJS, written in pure Swift.

## Overview

**TinyRedux** is a state management framework for iOS and macOS applications, inspired by Redux. It centralizes application state in a single Store and enforces a unidirectional data flow: views dispatch actions, actions flow through a pipeline, and the resulting state updates propagate back to the UI.

The framework adopts a **Supervised Redux Model** where three components cooperate in the same pipeline with distinct responsibilities:

- **Middleware** — handles side effects (network, I/O, timers) and can transform, block, or defer actions.
- **Reducer** — applies pure, deterministic state transitions.
- **Resolver** — provides structured error recovery when middleware fails.

Key capabilities:

- Native SwiftUI integration with automatic observation.
- Thread-safe dispatch from anywhere in the application.
- Capacity control and per-action rate limiting on the dispatch queue.
- One-shot subscriptions that react to state changes after reduction.
- Snapshot API for obtaining an encoded state projection at pipeline completion.
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
12. [Dispatch Pipeline](#12-dispatch-pipeline)
13. [Capacity and Rate Limiting](#13-capacity-and-rate-limiting)
14. [Logging](#14-logging)
15. [Flush, Suspend, Resume](#15-flush-suspend-resume)
16. [Tutorial: Redux Stack in a New App](#16-tutorial-redux-stack-in-a-new-app)
17. [Advanced Patterns](#17-advanced-patterns)
18. [Quick Reference](#18-quick-reference)

---

## 1. Introduction

TinyRedux is a Swift 6 framework for application state management based on the **Supervised Redux** model — a unidirectional data flow where middleware, reducer, and resolver cooperate within the same dispatch pipeline.

### Philosophy

- **Unidirectionality**: actions flow in a single direction through the pipeline.
- **Separation of concerns**: middleware handles side effects, reducers mutate state, resolvers handle errors.
- **Type-safe**: generic over `State` and `Action`, compiled with Strict Concurrency.
- **Observable**: the `Store` is `@Observable` and `@dynamicMemberLookup`, natively integrated with SwiftUI.
- **MainActor pipeline**: the entire pipeline is `@MainActor`, actions are dispatched from any isolation via `nonisolated dispatch`.

### Requirements

- Swift 6.0 toolchain
- iOS 18+ / macOS 15+
- Dependency: `swift-syntax` (for `@ReduxState`, `@ReduxAction` macros)

### Installation

Add the package to your `Package.swift`:

```swift
.package(path: "../Frameworks/TinyRedux")
```

Or as a remote dependency:

```swift
.package(url: "<repository-url>", from: "14.1.0")
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
| **State** | Mutable application state, `@Observable` |
| **Action** | Event describing an intent (`enum` Sendable) |
| **Reducer** | Pure state mutation (`O(1)`, synchronous, deterministic) |
| **Middleware** | Side effects (network, I/O, timers), intercepts actions pre-reducer |
| **Resolver** | Error handling from middleware, non-throwing recovery |
| **Store** | Central hub, owns state and pipeline, exposes dispatch API |

### Key Principles

1. **Single source of truth**: state is centralized in the Store.
2. **Read-only state for the UI**: views observe `State.ReadOnly`, only reducers write.
3. **Actions as intent descriptors**: they contain no logic, only data.
4. **Pure reducers**: no side effects, same input → same output.
5. **Middleware for side effects**: all asynchronous logic lives in middleware.

---

## 3. Quick Start

A minimal counter with TinyRedux:

```swift
import TinyRedux

// 1. State
@ReduxState
@Observable
@MainActor
final class CounterState: ReduxState {
  var count: Int = 0
}

// 2. Action
@ReduxAction
enum CounterAction: ReduxAction {
  case increment
  case decrement
  case reset
}

// 3. Reducer
let counterReducer = AnyReducer<CounterState, CounterAction>(id: "counter") { context in
  let (state, action) = context.args

  switch action {
  ///
  case .increment:
    state.count += 1

    return .next
  ///
  case .decrement:
    state.count -= 1

    return .next
  ///
  case .reset:
    state.count = 0

    return .next
  }
}

// 4. Store
let store = Store(
  initialState: CounterState(count: 0),
  middlewares: [],
  resolvers: [],
  reducers: [counterReducer]
)

// 5. Dispatch
store.dispatch(.increment)
store.dispatch(.decrement)
```

In SwiftUI:

```swift
import SwiftUI

struct CounterView: View {
  let store: Store<CounterState, CounterAction>

  var body: some View {
    VStack {
      Text("Counter: \(store.count)")
      HStack {
        Button("-") { store.dispatch(.decrement) }
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
@MainActor
public protocol ReduxState: AnyObject, Observable, Sendable {
  associatedtype ReadOnly: ReduxReadOnlyState where ReadOnly.State == Self
  var readOnly: ReadOnly { get }
}
```

The state is an `@Observable` class living on `@MainActor`. It must expose a `ReadOnly` projection that middleware and resolvers receive, ensuring only reducers can write.

### ReduxReadOnlyState Protocol

```swift
@MainActor
public protocol ReduxReadOnlyState: AnyObject, Observable, Sendable {
  associatedtype State: ReduxState
  init(_ state: State)
}
```

A mirror class of the state, exposing the same properties as computed get-only accessors that read from the original state via an `unowned` reference.

### @ReduxState Macro

The `@ReduxState` macro automatically generates:

1. The nested `ReadOnly` class with all `var` properties (excluding `@ObservationIgnored` ones) as computed get-only accessors.
2. The lazy `readOnly` property that creates the projection.
3. A designated `nonisolated` `init` with all parameters.

```swift
@ReduxState
@Observable
@MainActor
final class AppState: ReduxState {
  var username: String = ""
  var isLoading: Bool = false
  var items: [Item] = []

  @ObservationIgnored
  var internalCache: [String: Data] = [:]  // excluded from ReadOnly
}
```

The compiler generates:

```swift
@Observable
@MainActor
final class ReadOnly: ReduxReadOnlyState {
  private unowned let state: AppState
  init(_ state: AppState) { self.state = state }
  var username: String { state.username }
  var isLoading: Bool { state.isLoading }
  var items: [Item] { state.items }
}

@ObservationIgnored
lazy var readOnly = ReadOnly(self)

nonisolated
init(username: String, isLoading: Bool, items: [Item]) {
  self._username = username
  self._isLoading = isLoading
  self._items = items
}
```

### SwiftUI Integration

The `Store` is `@Observable` and `@dynamicMemberLookup`: views access state via key paths on the store:

```swift
struct MyView: View {
  let store: Store<AppState, AppAction>

  var body: some View {
    Text(store.username)           // access via dynamicMemberLookup
    if store.isLoading {
      ProgressView()
    }
  }
}
```

---

## 5. Actions

### ReduxAction Protocol

```swift
public protocol ReduxAction: CustomStringConvertible, Identifiable, Equatable, Sendable {
  var id: String { get }
  @MainActor var debugString: String { get }
}
```

Actions are `Sendable` enums that cross the `nonisolated` → `@MainActor` boundary.

- `id`: identifies the enum case (used for rate limiting and logging).
- `description`: stable nonisolated representation (default: `id`).
- `debugString`: rich `@MainActor` representation for logging (default: `description`).
- `Equatable`: comparison based on `id` (default), override for custom semantics.

### @ReduxAction Macro

The `@ReduxAction` macro synthesizes the `id` property from the case name:

```swift
@ReduxAction
enum AppAction: ReduxAction {
  case login(username: String, password: String)
  case logout
  case fetchProfile
  case setProfile(Profile)
  case showError(Error)
}
```

Generates:

```swift
public var id: String {
  switch self {
  case .login: return "login"
  case .logout: return "logout"
  case .fetchProfile: return "fetchProfile"
  case .setProfile: return "setProfile"
  case .showError: return "showError"
  }
}
```

### Custom debugString

To expose associated values in the log:

```swift
@MainActor
extension AppAction {
  var debugString: String {
    switch self {
    case .login(let username, _):
      return "login(username: \(username))"
    case .setProfile(let profile):
      return "setProfile(\(profile.name))"
    default:
      return description
    }
  }
}
```

---

## 6. Reducer

### Reducer Protocol

```swift
public protocol Reducer: Identifiable, Sendable {
  associatedtype S: ReduxState
  associatedtype A: ReduxAction
  var id: String { get }
  var reduce: ReduceHandler<S, A> { get }
}
```

The reducer is the **only component** in the pipeline authorized to mutate state. It must be:

- **Pure**: no side effects, no network calls, no I/O.
- **Deterministic**: same input → same output.
- **O(1)**: synchronous assignments only. Complex logic belongs in middleware.
- **Stateless**: does not use persistent local variables.

### ReducerContext

```swift
@MainActor
public struct ReducerContext<S: ReduxState, A: ReduxAction>: Sendable {
  public let state: S        // mutable state
  public let action: A       // action to reduce
  public var args: (S, A)    // destructuring convenience
}
```

### ReducerExit

```swift
public enum ReducerExit: Sendable {
  case next         // state mutated, logged, continues with subsequent reducers
  case done         // state mutated, logged, skips remaining reducers
  case defaultNext  // action not handled, not logged, continues
}
```

| Case | State Mutated | Logged | Subsequent Reducers |
|---|---|---|---|
| `.next` | Yes | Yes | Executed |
| `.done` | Yes | Yes | Skipped |
| `.defaultNext` | No | No | Executed |

### AnyReducer

Type-erased wrapper. Two creation modes:

```swift
// 1. From closure
let reducer = AnyReducer<AppState, AppAction>(id: "main") { context in
  let (state, action) = context.args

  switch action {
  ///
  case .setProfile(let profile):
    state.profile = profile

    return .next
  ///
  default:

    return .defaultNext
  }
}

// 2. From conformer
struct ProfileReducer: Reducer {
  let id = "profile"
  let reduce: ReduceHandler<AppState, AppAction> = { context in
    // ...

    return .next
  }
}

let reducer = AnyReducer(ProfileReducer())
```

### Rules

1. Always use `.defaultNext` for actions not handled by a reducer.
2. Use `.done` only when you want to prevent subsequent reducers from executing.
3. Reducers are executed in **declaration order** (forward order).
4. After all reducers execute, the subscription chain is evaluated.

---

## 7. Middleware

### Middleware Protocol

```swift
public protocol Middleware: Identifiable, Sendable {
  associatedtype S: ReduxState
  associatedtype A: ReduxAction
  var id: String { get }
  @MainActor func run(_ context: MiddlewareContext<S, A>) throws -> MiddlewareExit<S, A>
}
```

Middleware intercepts actions **before** reducers. It is the place for:

- Network calls
- I/O (database, file system)
- Timers and scheduling
- Validation with errors
- Action transformation
- Subscription registration

### MiddlewareContext

```swift
@MainActor
public struct MiddlewareContext<S: ReduxState, A: ReduxAction>: Sendable {
  public let state: S.ReadOnly                     // read-only state
  public let dispatch: ReduxDispatch<A>            // nonisolated, thread-safe
  public let action: A                             // current action
  public var args: MiddlewareArgs<S, A>            // (state, dispatch, action, subscribe, unsubscribe)
}
```

`args` destructures into a five-element tuple:

```swift
let (state, dispatch, action, subscribe, unsubscribe) = context.args
```

### MiddlewareExit

```swift
public enum MiddlewareExit<S: ReduxState, A: ReduxAction>: Sendable {
  case next                                       // forward, action handled
  case defaultNext                                // pass-through, not handled
  case nextAs(A)                                  // forward with modified action
  case resolve(SendableError)                     // route to resolver chain
  case exit(ExitResult)                           // .success/.done/.failure
  case task(TaskHandler<S>)                       // fire-and-forget async
  case deferred(DeferredTaskHandler<S, A>)        // async with resume
}
```

| Case | Pipeline | Reducer | Log |
|---|---|---|---|
| `.next` | Continues | Yes | Yes |
| `.defaultNext` | Continues | Yes | No |
| `.nextAs(action)` | Continues with new action | Yes | Yes |
| `.resolve(error)` | Resolver chain | Depends | Yes |
| `.exit(.success)` | Short-circuit to reducer | Yes | Yes |
| `.exit(.done)` | Terminates pipeline | No | Yes |
| `.exit(.failure(e))` | Terminates with error | No | Yes |
| `.task(body)` | Continues + async in parallel | Yes | Async |
| `.deferred(handler)` | Suspends, resumes on return | Depends | Async |
| `throw` | Resolver chain | Depends | Yes |

### .task — Fire-and-Forget

Launches an asynchronous task and the pipeline continues immediately (implicit `.next`):

```swift
return .task { state in
  try await api.sendAnalytics(event: action.id)
}
```

If the task throws an error, it is automatically routed to the resolver chain.

### .deferred — Suspended Pipeline

Suspends the pipeline waiting for the asynchronous result. The handler receives the read-only state and returns a `MiddlewareResumeExit`:

```swift
return .deferred { state in
  let user = try await api.fetchUser(id: state.userId)

  return .nextAs(.setUser(user))
}
```

```swift
public enum MiddlewareResumeExit<A: ReduxAction>: Sendable {
  case next                        // continue with current action
  case nextAs(A)                   // continue with modified action
  case resolve(SendableError)      // route to resolver
  case exit(ExitResult)            // .success/.done/.failure
}
```

### AnyMiddleware

```swift
// From closure
let logger = AnyMiddleware<AppState, AppAction>(id: "logger") { context in
  print("Action: \(context.action)")

  return .defaultNext
}

// From conformer
let wrapped = AnyMiddleware(MyMiddleware())
```

### Execution Order

Middleware are reversed internally: the **first in the array** receives the action **first**.

```swift
Store(
  initialState: state,
  middlewares: [middlewareA, middlewareB, middlewareC],  // A executes first
  resolvers: [],
  reducers: [reducer]
)
```

Flow: `middlewareA → middlewareB → middlewareC → reducer`

### subscribe / unsubscribe

Middleware can register post-reducer subscriptions via the context:

```swift
context.subscribe(id: "waitForLogin", when: { $0.isLoggedIn }) {

  return .fetchProfile
}
```

See [Section 10 — Subscriptions](#10-subscriptions) for details.

---

## 8. Resolver

### Resolver Protocol

```swift
public protocol Resolver: Identifiable, Sendable {
  associatedtype S: ReduxState
  associatedtype A: ReduxAction
  var id: String { get }
  @MainActor func run(_ context: ResolverContext<S, A>) -> ResolverExit<A>
}
```

The resolver handles errors originating from the middleware chain. It cannot throw exceptions — every recovery is expressed via `ResolverExit`.

### ResolverContext

```swift
@MainActor
public struct ResolverContext<S: ReduxState, A: ReduxAction>: Sendable {
  public let state: S.ReadOnly              // read-only state
  public let action: A                      // action that caused the error
  public let error: SendableError           // caught error
  public let origin: ReduxOrigin            // id of the middleware that originated the error
  public let dispatch: ReduxDispatch<A>     // nonisolated, thread-safe
  public var args: ResolverArgs<S, A>       // (state, dispatch, error, origin, action)
}
```

### ResolverExit

```swift
public enum ResolverExit<A: ReduxAction>: Sendable {
  case next                         // error handled, forward to next resolver
  case defaultNext                  // error not handled, pass-through
  case nextAs(SendableError, A)     // forward with modified error/action
  case reduce                       // recovery → reducer chain with current action
  case reduceAs(A)                  // recovery → reducer chain with modified action
  case exit(ExitResult)             // .success/.done = handled, .failure = unrecoverable
}
```

| Case | Error | Reducer | Pipeline |
|---|---|---|---|
| `.next` | Handled, forward | No (chain continues) | Subsequent resolvers |
| `.defaultNext` | Not handled | No | Subsequent resolvers |
| `.nextAs(e, a)` | Modified, forward | No | Subsequent resolvers |
| `.reduce` | Recovered | Yes (current action) | Short-circuit |
| `.reduceAs(a)` | Recovered | Yes (new action) | Short-circuit |
| `.exit(.success/.done)` | Handled | No | Terminated |
| `.exit(.failure)` | Unrecoverable | No | Terminated |

### Automatic Seed

If no resolver handles the error (all return `.next`/`.defaultNext`/`.nextAs`), the framework automatically logs the error as "unhandled" with `resolver("default", ...)` and calls `deferSnapshot?(.failure(error))`. No developer-side "default resolver" is required.

### AnyResolver

```swift
let errorResolver = AnyResolver<AppState, AppAction>(id: "error") { context in
  let (state, dispatch, error, origin, action) = context.args

  if error is NetworkError {
    dispatch(0, .showError(error))

    return .exit(.success)
  }

  return .defaultNext
}
```

### Execution Order

Like middleware, resolvers are reversed internally: the **first in the array** executes **first**.

---

## 9. Store

### Initialization

```swift
@Observable
@dynamicMemberLookup
public final class Store<S: ReduxState, A: ReduxAction>: Sendable
```

```swift
let store = Store(
  initialState: AppState(/* ... */),
  middlewares: [middleware1, middleware2],
  resolvers: [resolver1],
  reducers: [reducer1, reducer2],
  options: StoreOptions(dispatcherCapacity: 256),
  onLog: { log in print(log) }
)
```

The Store creates the Worker internally. There is no need to call `start()` — the pipeline is active immediately.

### Lifecycle

- **init**: creates Worker, Dispatcher, builds the pipeline via `buildDispatchProcess()`, starts the event loop Task.
- **deinit**: calls `dispatcher.finish()`, terminating the stream. The for-await in the Worker exits and the Task completes.

### Dispatch API

#### Fire-and-forget (variadic)

```swift
// nonisolated — callable from any isolation
store.dispatch(.increment)
store.dispatch(.increment, .increment, .decrement)
store.dispatch(maxDispatchable: 3, .fetchData)  // max 3 queued with the same id
```

#### Fire-and-forget (array)

```swift
store.dispatch(actions: [.increment, .decrement])
store.dispatch(maxDispatchable: 2, actions: actions)
```

#### Async with snapshot

```swift
let result: Result<Data, Error> = await store.dispatch(.saveProfile, snapshot: ProfileSnapshot.self)

switch result {
case .success(let data):
  // data contains the ProfileSnapshot JSON
case .failure(let error):
  // error from pipeline or encoding
}
```

### State Access

```swift
// Via dynamicMemberLookup (recommended)
let name = store.username      // @MainActor

// Via state property
let state = store.state        // S.ReadOnly, @MainActor
let name = state.username
```

### SwiftUI Binding

#### With dispatch

```swift
// Simple binding
let binding = store.bind(\.searchText) { newValue in
  .setSearchText(newValue)
}

// With get/set transformation
let binding = store.bind(
  \.selectedIndex,
  get: { Tab(rawValue: $0) ?? .home },
  set: { .selectTab($0) }
)

// With rate limiting
let binding = store.bind(\.slider, maxDispatchable: 1) { .setSlider($0) }
```

#### Simulator-only (preview)

```swift
#if targetEnvironment(simulator)
let binding = store.bind(\.username)  // direct read/write, bypasses pipeline
#endif
```

### Preview State

```swift
#if targetEnvironment(simulator)
store.previewState { state in
  state.username = "Preview User"
  state.isLoading = false
}
#endif
```

### Singleton

To manage the Store lifecycle at the application level:

```swift
let store = Singleton.getInstance {
  Store(
    initialState: AppState(/* ... */),
    middlewares: [/* ... */],
    resolvers: [/* ... */],
    reducers: [/* ... */]
  )
}
```

---

## 10. Subscriptions

Subscriptions are **one-shot post-reducer watchers** registered by middleware. They allow reacting to state changes after a reducer has completed.

### Registration

From `MiddlewareContext`:

```swift
// With state in builder
context.subscribe(
  id: "waitForAuth",
  when: { $0.isAuthenticated },
  then: { state in .loadDashboard(userId: state.userId) }
)

// Without state in builder
context.subscribe(
  id: "waitForAuth",
  when: { $0.isAuthenticated },
  then: { .loadDashboard }
)
```

From `args` destructuring (via `MiddlewareSubscribe`):

```swift
let (state, dispatch, action, subscribe, unsubscribe) = context.args

subscribe(
  id: "waitForData",
  when: { $0.dataLoaded },
  then: { .processData }
)
```

### Semantics

- **One-shot**: the subscription is removed after the first match.
- **Post-reducer**: the `when` predicate is evaluated after each reducer cycle.
- **Generation-aware**: subscriptions are cut by `flush()`/`suspend()`. A subscription with a stale generation is silently removed.
- **Dedupe-replace**: registering with the same `id` replaces the existing subscription.

### Unsubscribe

```swift
context.unsubscribe(id: "waitForAuth")
```

Or via `args`:

```swift
let (_, _, _, _, unsubscribe) = context.args
unsubscribe("waitForAuth")
```

### Evaluation Flow

```
reducer completes
    ↓
subscriptionChain()
    ↓
for each entry:
  ├── stale generation? → silently removed
  ├── when(readOnly) == true? → matched, removed, then(readOnly) → action
  │                              ↓
  │                         dispatcher.tryEnqueue(action)  // new pipeline entry
  └── when(readOnly) == false? → remains in registry
```

---

## 11. Snapshot API

The Snapshot API allows obtaining an encoded projection of the state at the end of the pipeline.

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

  @MainActor
  init(state: AppState.ReadOnly) {
    self.username = state.username
    self.email = state.email
  }
}
```

### Usage

```swift
let result = await store.dispatch(.updateProfile(name: "Alice"), snapshot: ProfileSnapshot.self)

switch result {
///
case .success(let data):
  let snapshot = try JSONDecoder().decode(ProfileSnapshot.self, from: data)
  print(snapshot.username)  // "Alice"
///
case .failure(let error):
  // EnqueueFailure, pipeline error, or encoding error
}
```

### Semantics

- The action goes through the same FIFO queue as `dispatch(maxDispatchable:_:)`.
- The caller is suspended (`async`) until the pipeline completes.
- The snapshot is created and encoded (`JSONEncoder`) at the terminal point of the pipeline (post-reducer or resolver exit).
- In the event of `flush()` during processing, the continuation receives `.failure(.staleGeneration)`.

---

## 12. Dispatch Pipeline

### Full Diagram

```
dispatch(action)  [nonisolated — any isolation]
    │
    ▼
Worker.Dispatcher.tryEnqueue
    │  check: isTerminated → isSuspended → generation → capacity → per-action limit
    │  success: pendingCount++, yield to AsyncStream
    │  failure: EnqueueFailure → log (or silent for staleGeneration)
    │
    ▼
AsyncStream(.unbounded) — FIFO transport
    │
    ▼
Worker Task [MainActor] — for await event in events
    │  defer { dispatcher.consume(id:) }
    │
    ├── stale generation? → snapshot .failure(.staleGeneration), skip pipeline
    │
    ▼
middlewareChain(readOnly, action, deferSnapshot)
    │
    │  The chain is built via fold (Array.reduce):
    │  seed = reduceChain(action, deferSnapshot)
    │  Each middleware wraps the next step
    │
    ├── Middleware A
    │   │
    │   ├── .next / .defaultNext → Middleware B (same action)
    │   ├── .nextAs(a2)          → Middleware B (modified action)
    │   ├── .resolve(error)      → resolveChain(error, action, "A", deferSnapshot)
    │   ├── .exit(.success)      → reduceChain(action, deferSnapshot)
    │   ├── .exit(.done)         → deferSnapshot?(.success(readOnly))
    │   ├── .exit(.failure(e))   → deferSnapshot?(.failure(e))
    │   ├── .task(body)          → runTask(body) + Middleware B (implicit .next)
    │   ├── .deferred(handler)   → Task { handler(readOnly) → MiddlewareResumeExit }
    │   │                          pipeline suspended, deferSnapshot threaded
    │   └── throws               → resolveChain(error, action, "A", deferSnapshot)
    │
    ├── Middleware B → ... → Middleware N
    │
    ▼
reduceChain(action, deferSnapshot)  [seed — terminal of the middleware chain]
    │
    │  for reducer in reducers (forward order):
    │    reducer.reduce(context) → ReducerExit
    │    .next       → continues
    │    .defaultNext → continues (no log)
    │    .done       → break
    │
    ├── subscriptionChain()  — evaluates post-reducer entries
    │
    ▼
deferSnapshot?(.success(readOnly))
    │
    ▼
dispatcher.consume(id:)  [defer — always executed]
```

### Resolver Chain (on error)

```
resolveChain(error, action, origin, deferSnapshot)
    │
    │  chain = resolvers.reduce(defaultResolver) { fold }
    │
    ├── Resolver A
    │   ├── .next / .defaultNext  → Resolver B (same error/action)
    │   ├── .nextAs(e2, a2)       → Resolver B (modified error/action)
    │   ├── .reduce               → reduceChain(action, deferSnapshot)
    │   ├── .reduceAs(a2)         → reduceChain(a2, deferSnapshot)
    │   └── .exit(result)         → deferSnapshot?(.success(readOnly))
    │
    └── Seed (auto-terminal):
          onLog(.resolver("default", action, .zero, .exit(.failure(error)), error))
          deferSnapshot?(.failure(error))
```

---

## 13. Capacity and Rate Limiting

### dispatcherCapacity

Configured via `StoreOptions`:

```swift
let store = Store(
  initialState: state,
  middlewares: [],
  resolvers: [],
  reducers: [],
  options: StoreOptions(dispatcherCapacity: 128)
)
```

- **Default**: 256
- **Effective minimum**: 1 (values ≤ 0 are clamped with assert in debug)
- **Semantics**: counts queued + in-flight actions. The slot is freed only after the worker has completed the pipeline (reducer + synchronous middleware).
- **Does not limit**: `.task` / `.deferred` already started. Only re-entrant dispatches from those tasks go through `tryEnqueue`.

### maxDispatchable (Per-Action Rate Limiting)

The `maxDispatchable` parameter limits the number of actions with the same `id` present in the queue:

```swift
store.dispatch(maxDispatchable: 1, .fetchData)  // max 1 .fetchData in queue
store.dispatch(maxDispatchable: 3, .scroll(offset: y))  // max 3 .scroll
```

- `0` (default): no per-action limit.
- The per-action counter (`counts[id]`) is decremented when the worker calls `consume(id:)`.

### EnqueueFailure

```swift
public enum EnqueueFailure: Error, Equatable, Sendable {
  case bufferLimitReached       // pendingCount ≥ dispatcherCapacity
  case maxDispatchableReached   // counts[id] ≥ limit
  case suspended                // dispatcher suspended (testing-only)
  case staleGeneration          // generation mismatch (post-flush)
  case terminated               // stream terminated (post-deinit)
}
```

The `.bufferLimitReached`, `.maxDispatchableReached`, `.suspended`, and `.terminated` failures generate a `Store.Log.store(...)` log. The `.staleGeneration` failure is **silent** (expected outcome post-flush).

For `dispatch(_:snapshot:) async`, the failure is returned as `.failure(EnqueueFailure)` in the `Result`.

---

## 14. Logging

### Store.Log

```swift
public enum Log: Sendable {
  case middleware(String, A, Duration, MiddlewareExit<S, A>)
  case reducer(String, A, Duration, ReducerExit)
  case resolver(String, A, Duration, ResolverExit<A>, SendableError)
  case subscription(Subscription)
  case store(String)
}
```

| Case | Parameters |
|---|---|
| `.middleware` | component id, action, duration, exit signal |
| `.reducer` | component id, action, duration, exit signal |
| `.resolver` | component id, action, duration, exit signal, error |
| `.subscription` | subscription event (see below) |
| `.store` | text message (flush, suspend, resume, discard) |

### Automatic Timing

The framework automatically measures the execution time of every component. The timestamp is captured before `run()`/`reduce()` and the elapsed time is calculated after the enum return.

For `.task` and `.deferred`: timing measures the async task duration, not the synchronous dispatch.

### What Gets Logged

| Component | `.defaultNext` | Other exits |
|---|---|---|
| Middleware | **Not logged** | Logged |
| Reducer | **Not logged** | Logged |
| Resolver | **Not logged** | Logged |

### Store.Log.Subscription

```swift
public enum Subscription: Sendable {
  case subscribed(String, String, A, Duration)     // registeredBy, subId, origin, elapsed
  case executed(String, String, A, Duration, A)    // registeredBy, subId, origin, elapsed, dispatched action
  case unsubscribed(String, String, Duration)      // canceller, subId, elapsed
}
```

- `.subscribed`: emitted when `context.subscribe(...)` registers an entry.
- `.executed`: emitted when a subscription matches and the action is enqueued. The fifth parameter is the action produced by `then(readOnly)`.
- `.unsubscribed`: emitted when `context.unsubscribe(id:)` removes an entry. The first parameter is the id of the middleware that called unsubscribe, not the original registrant. Correlate with `.subscribed` via `subId`.

### Log Handler Configuration

```swift
let store = Store(
  initialState: state,
  middlewares: middlewares,
  resolvers: resolvers,
  reducers: reducers,
  onLog: { log in
    switch log {
    ///
    case .middleware(let id, let action, let duration, let exit):
      print("[\(id)] \(action.debugString) → \(exit) (\(duration))")
    ///
    case .reducer(let id, let action, let duration, let exit):
      print("[\(id)] \(action.debugString) → \(exit) (\(duration))")
    ///
    case .resolver(let id, let action, let duration, let exit, let error):
      print("[\(id)] \(action.debugString) → \(exit) error: \(error) (\(duration))")
    ///
    case .subscription(let event):
      print("Subscription: \(event)")
    ///
    case .store(let message):
      print("Store: \(message)")
    }
  }
)
```

---

## 15. Flush, Suspend, Resume

### flush()

```swift
nonisolated public func flush()
```

Invalidates all queued actions by incrementing the Dispatcher's `generation` counter.

- Actions already in the stream with a stale generation are skipped by the worker (snapshot continuation → `.failure(.staleGeneration)`).
- Rate-limit counters (`counts`) are reset.
- `pendingCount` is **not** reset: stale events free their slot when the worker drains them.
- The currently executing action is not interrupted.

```swift
store.flush()  // nonisolated, callable from any context
```

### suspend() — Testing Only

```swift
nonisolated public func suspend()
```

Executes `flush()` and sets `isSuspended = true` in a single atomic operation. All new actions are rejected with `EnqueueFailure.suspended` until `resume()`.

**Warning**: testing only. In production this can cause silent loss of actions.

### resume() — Testing Only

```swift
nonisolated public func resume()
```

Re-enables the Dispatcher after a `suspend()`. New actions are accepted normally.

---

## 16. Tutorial: Redux Stack in a New App

This tutorial walks through creating a complete "Todo List" app with TinyRedux.

### Step 1: Define the State

```swift
import TinyRedux

@ReduxState
@Observable
@MainActor
final class TodoState: ReduxState {
  var items: [TodoItem] = []
  var isLoading: Bool = false
  var error: String? = nil
  var filter: Filter = .all
}

struct TodoItem: Identifiable, Codable, Sendable {
  let id: UUID
  var title: String
  var isCompleted: Bool
}

enum Filter: Sendable {
  case all, active, completed
}
```

### Step 2: Define the Actions

```swift
@ReduxAction
enum TodoAction: ReduxAction {
  case addTodo(String)
  case toggleTodo(UUID)
  case deleteTodo(UUID)
  case setFilter(Filter)
  case fetchTodos
  case setTodos([TodoItem])
  case setLoading(Bool)
  case setError(String?)
}
```

### Step 3: Create the Reducer

```swift
let todoReducer = AnyReducer<TodoState, TodoAction>(id: "todo") { context in
  let (state, action) = context.args

  switch action {
  ///
  case .addTodo(let title):
    state.items.append(TodoItem(id: UUID(), title: title, isCompleted: false))

    return .next
  ///
  case .toggleTodo(let id):
    guard let index = state.items.firstIndex(where: { $0.id == id }) else {

      return .defaultNext
    }
    state.items[index].isCompleted.toggle()

    return .next
  ///
  case .deleteTodo(let id):
    state.items.removeAll { $0.id == id }

    return .next
  ///
  case .setFilter(let filter):
    state.filter = filter

    return .next
  ///
  case .setTodos(let items):
    state.items = items

    return .next
  ///
  case .setLoading(let loading):
    state.isLoading = loading

    return .next
  ///
  case .setError(let error):
    state.error = error

    return .next
  ///
  default:

    return .defaultNext
  }
}
```

### Step 4: Create the Middleware

```swift
let todoMiddleware = AnyMiddleware<TodoState, TodoAction>(id: "todoAPI") { context in
  let (state, dispatch, action, subscribe, _) = context.args

  switch action {
  ///
  case .fetchTodos:
    dispatch(0, .setLoading(true))

    return .deferred { _ in
      let todos = try await TodoAPI.fetchAll()

      return .nextAs(.setTodos(todos))
    }
  ///
  case .setTodos:
    dispatch(0, .setLoading(false), .setError(nil))

    return .next
  ///
  default:

    return .defaultNext
  }
}
```

### Step 5: Create the Resolver

```swift
let todoResolver = AnyResolver<TodoState, TodoAction>(id: "todoError") { context in
  let (_, dispatch, error, origin, action) = context.args

  if error is URLError {
    dispatch(0, .setLoading(false), .setError("Network error: \(error.localizedDescription)"))

    return .exit(.success)
  }

  return .defaultNext
}
```

### Step 6: Configure the Store

```swift
typealias TodoStore = Store<TodoState, TodoAction>

extension Singleton {
  static var todoStore: TodoStore {
    getInstance {
      Store(
        initialState: TodoState(items: [], isLoading: false, error: nil, filter: .all),
        middlewares: [todoMiddleware],
        resolvers: [todoResolver],
        reducers: [todoReducer],
        onLog: { log in
          #if DEBUG
          print("📋 \(log)")
          #endif
        }
      )
    }
  }
}
```

### Step 7: Create the SwiftUI View

```swift
import SwiftUI

struct TodoListView: View {
  let store = Singleton.todoStore

  var body: some View {
    NavigationStack {
      _main_
        .navigationTitle("Todo")
        .toolbar { _toolbar_ }
        .onAppear { store.dispatch(.fetchTodos) }
    }
  }

  @ViewBuilder
  var _main_: some View {
    if store.isLoading {
      ProgressView()
    } else {
      _list_
    }
  }

  @ViewBuilder
  var _list_: some View {
    List {
      ForEach(filteredItems) { item in
        _row(for: item)
      }
      .onDelete { offsets in
        for index in offsets {
          store.dispatch(.deleteTodo(filteredItems[index].id))
        }
      }
    }
  }

  @ViewBuilder
  func _row(for item: TodoItem) -> some View {
    HStack {
      Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
        .onTapGesture { store.dispatch(.toggleTodo(item.id)) }
      Text(item.title)
        .strikethrough(item.isCompleted)
    }
  }

  @ViewBuilder
  var _toolbar_: some View {
    Menu {
      Button("All") { store.dispatch(.setFilter(.all)) }
      Button("Active") { store.dispatch(.setFilter(.active)) }
      Button("Completed") { store.dispatch(.setFilter(.completed)) }
    } label: {
      Image(systemName: "line.3.horizontal.decrease.circle")
    }
  }

  var filteredItems: [TodoItem] {
    switch store.filter {
    case .all: store.state.items
    case .active: store.state.items.filter { !$0.isCompleted }
    case .completed: store.state.items.filter { $0.isCompleted }
    }
  }
}
```

### Step 8: Binding for Input

```swift
// In a middleware that handles input
let searchBinding = store.bind(\.searchText) { text in
  .setSearchText(text)
}

// In SwiftUI
TextField("Search...", text: searchBinding)
```

---

## 17. Advanced Patterns

### 17.1. Middleware Composition

Middleware can be composed in a chain. Each middleware decides whether the action is relevant to it:

```swift
let authMiddleware = AnyMiddleware<AppState, AppAction>(id: "auth") { context in
  switch context.action {
  ///
  case .login(let credentials):

    return .deferred { _ in
      let token = try await AuthService.login(credentials)

      return .nextAs(.setToken(token))
    }
  ///
  case .logout:

    return .task { _ in
      await AuthService.logout()
    }
  ///
  default:

    return .defaultNext
  }
}

let analyticsMiddleware = AnyMiddleware<AppState, AppAction>(id: "analytics") { context in
  Analytics.track(event: context.action.id)

  return .defaultNext
}

// analytics sees ALL actions, auth only login/logout
let store = Store(
  initialState: state,
  middlewares: [analyticsMiddleware, authMiddleware],
  resolvers: [],
  reducers: [reducer]
)
```

### 17.2. Resolver Short-Circuit

A resolver can recover from an error and inject an action into the reducer:

```swift
let retryResolver = AnyResolver<AppState, AppAction>(id: "retry") { context in
  if context.error is TimeoutError, context.state.retryCount < 3 {
    context.dispatch(0, .incrementRetry)

    return .reduceAs(.setLoading(true))  // bypasses middleware, goes directly to reducer
  }

  return .defaultNext
}
```

### 17.3. Deferred for Authentication

Common pattern: a middleware intercepts an action that requires authentication:

```swift
let authGuard = AnyMiddleware<AppState, AppAction>(id: "authGuard") { context in
  guard context.state.token != nil else {

    return .resolve(AuthError.notAuthenticated)
  }

  return .defaultNext
}

let authResolver = AnyResolver<AppState, AppAction>(id: "authRecover") { context in
  if context.error is AuthError {
    context.dispatch(0, .showLoginScreen)

    return .exit(.success)
  }

  return .defaultNext
}
```

### 17.4. Subscriptions for Reactive Side Effects

Subscriptions allow reacting to state changes without polling:

```swift
let onboardingMiddleware = AnyMiddleware<AppState, AppAction>(id: "onboarding") { context in
  switch context.action {
  ///
  case .appLaunched:
    context.subscribe(
      id: "firstLoginComplete",
      when: { $0.isLoggedIn && $0.profileLoaded },
      then: { .completeOnboarding }
    )

    return .next
  ///
  default:

    return .defaultNext
  }
}
```

### 17.5. Exit Success vs Done

- `.exit(.success)`: the action is handled by the middleware, but the reducer is still executed.
- `.exit(.done)`: the action is fully handled by the middleware, the pipeline terminates without running the reducer.

```swift
// Caching: if data is in cache, skip the reducer
let cacheMiddleware = AnyMiddleware<AppState, AppAction>(id: "cache") { context in
  switch context.action {
  ///
  case .fetchProfile:
    if context.state.profileCacheValid {

      return .exit(.done)  // no reducer, no fetch
    }

    return .defaultNext
  ///
  default:

    return .defaultNext
  }
}
```

---

## 18. Quick Reference

### Protocols

| Protocol | Constraints | Role |
|---|---|---|
| `ReduxState` | `@MainActor, AnyObject, Observable, Sendable` | Mutable state |
| `ReduxReadOnlyState` | `@MainActor, AnyObject, Observable, Sendable` | Read-only projection |
| `ReduxAction` | `CustomStringConvertible, Identifiable, Equatable, Sendable` | Dispatchable action |
| `ReduxStateSnapshot` | `Codable, Sendable` | Encodable snapshot |
| `Middleware` | `Identifiable, Sendable` | Side effects |
| `Reducer` | `Identifiable, Sendable` | State mutation |
| `Resolver` | `Identifiable, Sendable` | Error recovery |

### Value Types

| Type | Generics | Role |
|---|---|---|
| `AnyMiddleware<S, A>` | `ReduxState, ReduxAction` | Middleware type-erasure |
| `AnyReducer<S, A>` | `ReduxState, ReduxAction` | Reducer type-erasure |
| `AnyResolver<S, A>` | `ReduxState, ReduxAction` | Resolver type-erasure |
| `MiddlewareContext<S, A>` | `ReduxState, ReduxAction` | Middleware context |
| `ReducerContext<S, A>` | `ReduxState, ReduxAction` | Reducer context |
| `ResolverContext<S, A>` | `ReduxState, ReduxAction` | Resolver context |
| `MiddlewareSubscribe<S, A>` | `ReduxState, ReduxAction` | Registration callable |
| `StoreOptions` | — | Store configuration |
| `ExitResult` | — | Pipeline exit outcome |

### Enums

| Enum | Generics | Cases |
|---|---|---|
| `MiddlewareExit<S, A>` | `ReduxState, ReduxAction` | `.next, .defaultNext, .nextAs, .resolve, .exit, .task, .deferred` |
| `MiddlewareResumeExit<A>` | `ReduxAction` | `.next, .nextAs, .resolve, .exit` |
| `ReducerExit` | — | `.next, .done, .defaultNext` |
| `ResolverExit<A>` | `ReduxAction` | `.next, .defaultNext, .nextAs, .reduce, .reduceAs, .exit` |
| `ExitResult` | — | `.success, .done, .failure(SendableError)` |
| `EnqueueFailure` | — | `.bufferLimitReached, .maxDispatchableReached, .suspended, .staleGeneration, .terminated` |
| `Store.Log` | — | `.middleware, .reducer, .resolver, .subscription, .store` |
| `Store.Log.Subscription` | — | `.subscribed, .executed, .unsubscribed` |

### Public Type Aliases

| Alias | Signature |
|---|---|
| `SendableError` | `any Error` |
| `ReduxOrigin` | `String` |
| `ReduxDispatch<A>` | `@Sendable (UInt, A...) -> Void` |
| `ReduxEncodedSnapshot` | `Result<Data, Error>` |
| `LogHandler<S, A>` | `@MainActor @Sendable (Store<S, A>.Log) -> Void` |
| `MiddlewareHandler<S, A>` | `@MainActor (MiddlewareContext<S, A>) throws -> MiddlewareExit<S, A>` |
| `ReduceHandler<S, A>` | `@MainActor (ReducerContext<S, A>) -> ReducerExit` |
| `ResolveHandler<S, A>` | `@MainActor (ResolverContext<S, A>) -> ResolverExit<A>` |
| `UnsubscribeHandler` | `@MainActor @Sendable (String) -> Void` |
| `TaskHandler<S>` | `@Sendable (S.ReadOnly) async throws -> Void` |
| `DeferredTaskHandler<S, A>` | `@Sendable (S.ReadOnly) async throws -> MiddlewareResumeExit<A>` |
| `SubscriptionPredicate<S>` | `@MainActor @Sendable (S.ReadOnly) -> Bool` |
| `SubscriptionHandler<S, A>` | `@MainActor @Sendable (S.ReadOnly) -> A` |

### Macros

| Macro | Target | Generates |
|---|---|---|
| `@ReduxState` | `class` | `ReadOnly` class, `readOnly` property, designated `init` |
| `@ReduxAction` | `enum` | `var id: String` from case names |

### Store API

| Method | Isolation | Returns |
|---|---|---|
| `dispatch(maxDispatchable:_:)` | `nonisolated` | `Void` |
| `dispatch(maxDispatchable:actions:)` | `nonisolated` | `Void` |
| `dispatch(_:snapshot:)` | `nonisolated async` | `Result<Data, Error>` |
| `flush()` | `nonisolated` | `Void` |
| `suspend()` | `nonisolated` | `Void` |
| `resume()` | `nonisolated` | `Void` |
| `state` | `@MainActor` | `S.ReadOnly` |
| `bind(_:maxDispatchable:_:)` | `@MainActor` | `Binding<T>` |
| `bind(_:maxDispatchable:get:set:)` | `@MainActor` | `Binding<U>` |
| `bind(_:)` (simulator) | `@MainActor` | `Binding<T>` |
| `previewState(_:)` (simulator) | `@MainActor` | `Void` |
| `subscript(dynamicMember:)` | `@MainActor` | `Value` |
