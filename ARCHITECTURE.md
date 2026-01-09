# TinyRedux — Technical Specifications

|              |                                     |
|--------------|-------------------------------------|
| **Version**  | 1.0.20                              |
| **Platform** | iOS 18+, macOS 15+                  |
| **Swift**    | 6.0 (Strict Concurrency)            |

---

## Table of Contents

1. [Architectural Overview](#1-architectural-overview)
2. [Protocols](#2-protocols)
3. [ReduxStore](#3-reduxstore)
4. [Worker](#4-worker)
5. [Dispatcher](#5-dispatcher)
6. [Pipeline Execution](#6-pipeline-execution)
7. [Middleware Chain](#7-middleware-chain)
8. [Reducer Chain](#8-reducer-chain)
9. [Resolver Chain](#9-resolver-chain)
10. [Async Effects](#10-async-effects)
11. [Subscriptions](#11-subscriptions)
12. [Snapshot API](#12-snapshot-api)
13. [Streaming Snapshots](#13-streaming-snapshots)
14. [Rate Control & Backpressure Diagnostics](#14-rate-control--backpressure-diagnostics)
15. [Modules, Maps & Slices](#15-modules-maps--slices)
16. [Logging](#16-logging)
17. [Type Aliases](#17-type-aliases)
18. [Macros](#18-macros)
19. [Concurrency Model](#19-concurrency-model)
20. [Error Flow](#20-error-flow)
21. [Memory Management](#21-memory-management)

---

## 1. Architectural Overview

TinyRedux implements the **Supervised Redux** model — a unidirectional data flow where
middleware, reducer, and resolver cooperate in a serialized dispatch pipeline.

### Component Hierarchy

```
ReduxStore<S, A> [@Observable, @dynamicMemberLookup, ReduxModule, Sendable]
├── _state: S                              [@MainActor let]
└── worker: Worker                         [let, Sendable]
      ├── dispatcher: Dispatcher           [let, Sendable]
      │     ├── stream: AsyncStream        [.unbounded, consumed by the loop]
      │     ├── continuation               [Sendable, thread-safe yield]
      │     └── mutex: Mutex<RateState>    [counts (.limit) + lastTime (.throttle)]
      ├── state: S                         [@MainActor let — same object as _state]
      ├── reducers: [AnyReduxReducer]      [let, forward order]
      ├── middlewares: [AnyMiddleware]     [let, folded reversed at run]
      ├── resolvers: [AnyResolver]         [let, folded reversed at run]
      ├── options: StoreOptions            [let]
      ├── onLog: ReduxLogHandler?          [let]
      ├── task: Task<Void, Never>?         [@MainActor — the event loop]
      ├── childTasks: [UUID: Task]         [@MainActor — .task/.deferred effects]
      ├── subscriptions: [String: Subscription] [@MainActor — State→Action]
      ├── streams: Streams                 [@MainActor — active snapshot streams]
      ├── encoder: JSONEncoder             [@MainActor — single shared encoder]
      └── pressureHits / pressureLastWarned[@MainActor — backpressure diagnostics]
```

### General Flow

```
Caller (any isolation)
    │
    ▼
ReduxStore.dispatch()      [nonisolated]
    │
    ▼
Worker.dispatch()          [nonisolated]
    │
    ▼
Dispatcher.tryEnqueue()    [nonisolated; rate gate — .none lock-free, .limit/.throttle Mutex]
    │
    ▼
AsyncStream(.unbounded)    [FIFO transport of TaggedActionEvent]
    │
    ▼
Worker loop                [@MainActor — for await event in events]
    │   runProcess(event):
    │     trackPressure(action.id)
    │     runMiddleware(action, makeTerminal(...))
    │     dispatcher.consume(id:counted:)
    │
    ├── runMiddleware       [fold, declaration order] → MiddlewareExit
    ├── reduceChain         [seed: reducers forward + subscriptions + streams + terminal]
    └── resolveChain        [fold, declaration order; only on error] → ResolverExit
```

The pipeline is **not** pre-built into a closure graph: the worker folds the middleware and
resolver arrays on each action. There is no generation/suspend/resume/capacity machinery —
the buffer is unbounded and ordering is plain FIFO.

---

## 2. Protocols

### 2.1 ReduxState

```swift
public protocol ReduxState: AnyObject, Observable, Sendable {
  associatedtype ReadOnly: ReduxReadOnlyState where ReadOnly.State == Self
  @MainActor var readOnly: ReadOnly { get }
}
```

- `AnyObject`: reference type; reducers mutate properties in place.
- `Observable`: SwiftUI observation.
- `Sendable`: the state is owned by the store across isolation boundaries. Conformers are typically `@MainActor` so mutable observable state stays main-actor isolated.
- `ReadOnly`: the read-only projection; `ReadOnly.State == Self` ties the two together. The `@ReduxState` macro generates it as a nested class whose properties forward to the state via `unowned let state`.

### 2.2 ReduxReadOnlyState

```swift
public protocol ReduxReadOnlyState: AnyObject, Observable, Sendable {
  associatedtype State: ReduxState
  init(_ state: State)
}
```

Created once, lazily, via the state's `readOnly` property.

### 2.3 ReduxMappedState

```swift
public protocol ReduxMappedState: ReduxState {}
```

Marker refining `ReduxState` for a module state that is **projected field-by-field** (via
`ReduxBinding`) onto split, app-owned sub-states (`.scattered` composition) rather than
owning its storage. Because it refines `ReduxState`, the store/worker/reducer treat it
uniformly. A `@ReduxMappedState` class writes the `ReduxMappedState` conformance inline; the
macro adds only the `Observable` marker conformance (an inline state conformance would break
the `ReadOnly`↔`State` inference cycle).

### 2.4 ReduxAction

```swift
public protocol ReduxAction: CustomStringConvertible, CustomDebugStringConvertible,
                             Identifiable, Equatable, Sendable {
  var id: String { get }
}
extension ReduxAction {
  var description: String { id }
  var debugDescription: String { id }
  static func ==(lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }  // case-only identity
}
```

`id` (the case name) identifies the action for logging and rate control. Equality is
case-only by default (associated values ignored) — override `==` for payload-sensitive
equality.

### 2.5 ReduxModule

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

Existential-friendly facade the UI depends on. `bind` has a default implementation derived
from `state` + `dispatch`. Both `ReduxStore` and `ReduxStoreSlice` conform.

### 2.6 Middleware

```swift
public protocol Middleware<S, A>: Identifiable, Sendable {
  associatedtype S: ReduxState
  associatedtype A: ReduxAction
  var id: String { get }
  @MainActor func run(_ context: MiddlewareContext<S, A>) throws -> MiddlewareExit<S, A>
}
```

`run` is `@MainActor` and synchronous; a `throw` is routed to the resolver. Asynchrony
escapes via `.task` / `.deferred`.

### 2.7 ReduxReducer

```swift
public protocol ReduxReducer: Identifiable, Sendable {
  associatedtype S: ReduxState
  associatedtype A: ReduxAction
  var id: String { get }
  var reduce: ReduxReduceHandler<S, A> { get }   // @MainActor (ReduxReducerContext) -> ReduxReducerExit
}
```

The only writer. Pure, deterministic, synchronous, non-throwing.

### 2.8 Resolver

```swift
public protocol Resolver<S, A>: Identifiable, Sendable {
  associatedtype S: ReduxState
  associatedtype A: ReduxAction
  var id: String { get }
  @MainActor func run(_ context: ResolverContext<S, A>) -> ResolverExit<A>
}
```

The error branch. Synchronous, `@MainActor`, non-throwing — every recovery is a
`ResolverExit`.

### 2.9 ReduxStateSnapshot

```swift
public protocol ReduxStateSnapshot<S>: Codable, Sendable {
  associatedtype S: ReduxState
  @MainActor init(state: S.ReadOnly)
}
```

Immutable, transportable projection captured at a pipeline terminal, JSON-encoded to `Data`
by the worker.

---

## 3. ReduxStore

### Definition

```swift
@Observable
@dynamicMemberLookup
public final class ReduxStore<S, A>: ReduxModule, Sendable
where S: ReduxState, A: ReduxAction {
  @MainActor let _state: S
  let worker: Worker
}
```

### Init

```swift
public init(
  initialState state: S,
  reducers: [AnyReduxReducer<S, A>],
  middlewares: [AnyMiddleware<S, A>] = [],
  resolvers: [AnyResolver<S, A>] = [],
  options: StoreOptions = .init(),
  onLog: ReduxLogHandler<S, A>? = nil
)
```

Assigns `_state` and constructs the `Worker` (which owns the dispatcher and starts the
main-actor event loop). `reducers` is required; everything else defaults.

### Deinit

```swift
deinit {
  worker.dispatcher.finish()
  let worker = self.worker
  Task { @MainActor in worker.finishAllStreams() }
}
```

`finish()` ends the dispatcher stream (so the worker loop ends). Active snapshot streams are
finished eagerly via a main-actor hop — a nonisolated `deinit` cannot reach the `@MainActor`
`Streams` registry directly; the captured `worker` keeps the instance alive until the hop
completes.

### State Access

```swift
@MainActor public var state: S.ReadOnly { _state.readOnly }

@MainActor
public subscript<Value>(dynamicMember keyPath: KeyPath<S.ReadOnly, Value>) -> Value {
  _state.readOnly[keyPath: keyPath]
}
```

### Dispatch (ReduxStore+dispatch.swift)

```swift
nonisolated public func dispatch(_ actions: A...) {
  for action in actions { worker.dispatch(action) }
}

nonisolated public func dispatch(_ action: A, rate: DispatchRateLimit) {
  worker.dispatch(action, rate: rate)
}
```

`ReduxModule.dispatch(_ actions: A...)` is satisfied by the variadic overload. Snapshot
dispatch and `slice(_:)` / `previewState(_:)` live in dedicated extensions (Sections 12, 13,
15).

---

## 4. Worker

`Store.Worker` (nested in `ReduxStore`) owns the live state and the three component arrays,
and runs the dispatch loop.

### Definition

```swift
extension ReduxStore {
  final class Worker: Sendable {
    @MainActor let state: S
    let reducers: [AnyReduxReducer<S, A>]
    let middlewares: [AnyMiddleware<S, A>]
    let resolvers: [AnyResolver<S, A>]
    let dispatcher: Dispatcher
    let onLog: ReduxLogHandler<S, A>?
    let options: StoreOptions

    @MainActor private var task: Task<Void, Never>?
    @MainActor private var childTasks: [UUID: Task<Void, Never>]
    @MainActor private var subscriptions: [String: Subscription<S, A>] = [:]
    @MainActor let streams = Streams()
    @MainActor let encoder = JSONEncoder()
    @MainActor private var pressureHits: [String: [ContinuousClock.Instant]] = [:]
    @MainActor private var pressureLastWarned: [String: ContinuousClock.Instant] = [:]
  }
}
```

### Init & Event Loop

```swift
self.dispatcher = Dispatcher()
let events = dispatcher.events
self.task = Task { @MainActor [weak self] in
  for await event in events {
    guard let self else { return }
    runProcess(event)
  }
}
```

`[weak self]` lets the worker deallocate; the loop ends when the dispatcher finishes or the
worker is gone.

### Dispatch Entry Points

```swift
@discardableResult nonisolated
func dispatch(_ action: A, rate: DispatchRateLimit = .none) -> Result<Void, ReduxError> {
  let result = dispatcher.tryEnqueue(action, rate: rate)
  if case .failure(let error) = result {
    onLog?(.store("discarded action '\(action.id)': \(error)"))
  }
  return result
}

nonisolated
func dispatch(_ action: A, snapshot request: SnapshotRequest<S>) {
  let result = dispatcher.tryEnqueue(action, rate: .none, onTerminal: request)
  if case .failure(let error) = result {
    request.continuation.resume(returning: .failure(error))   // never hang the caller
    onLog?(.snapshot(.failed(action: action, error: error)))
  }
}
```

### runProcess

```swift
@MainActor
private func runProcess(_ event: TaggedActionEvent) {
  trackPressure(event.action.id)
  runMiddleware(event.action, makeTerminal(event.action, event.onTerminal))
  dispatcher.consume(id: event.action.id, counted: event.counted)
}
```

`consume` is called for every event (releases a `.limit` slot when `counted`). The
single-shot terminal is built from the event's optional `SnapshotRequest`.

### makeTerminal

Builds the once-only `SnapshotTerminal` from a request: `.success(readOnly)` encodes with
the shared encoder and resumes `.success(Data)` (or `.failure` on encode error and logs
`.snapshot(.resolved/.failed)`); `.failure(error)` resumes `.failure`. Returns `nil` when
the event carries no request — the normal dispatch path threads `nil` and skips all terminal
work.

---

## 5. Dispatcher

```swift
extension ReduxStore.Worker {
  typealias TaggedActionEvent = (action: A, counted: Bool, onTerminal: SnapshotRequest<S>?)

  final class Dispatcher: Sendable {
    private struct RateState {
      var counts:   [String: Int] = [:]                     // .limit (pending count per id)
      var lastTime: [String: ContinuousClock.Instant] = [:] // .throttle (last admitted per id)
    }
    private let mutex = Mutex(RateState())
    private let stream: AsyncStream<TaggedActionEvent>
    private let continuation: AsyncStream<TaggedActionEvent>.Continuation
  }
}
```

The stream is created with `bufferingPolicy: .unbounded`. The nonisolated write side
(`tryEnqueue`) feeds the main-actor read side (`events`, drained by the worker loop).

### tryEnqueue

```swift
@discardableResult nonisolated
func tryEnqueue(_ action: A, rate limit: DispatchRateLimit = .none,
                onTerminal: SnapshotRequest<S>? = nil) -> Result<Void, ReduxError>
```

| Rate | Behaviour |
|---|---|
| `.none` | lock-free fast path: `yield(counted: false)` |
| `.limit(max)` | under the mutex, admit iff `counts[id] < max`, then `counts[id] += 1` and `yield(counted: true)`; else `.failure(.rateLimited)` |
| `.throttle(interval)` | under the mutex, admit iff `now - lastTime[id] >= interval`, set `lastTime[id] = now`, `yield(counted: false)`; else `.failure(.rateLimited)` |

`yield` maps the `AsyncStream` `YieldResult` to a `Result`: `.enqueued → .success`,
`.terminated → .failure(.terminated)`. `.dropped` cannot occur (the buffer is unbounded).

### consume

```swift
nonisolated func consume(id: String, counted: Bool) {
  guard counted else { return }
  mutex.withLock { state in
    guard let current = state.counts[id] else { return }
    if current > 1 { state.counts[id] = current - 1 } else { state.counts[id] = nil }
  }
}
```

Releases one `.limit` slot after the worker finished processing the event. `.none` /
`.throttle` events are not counted, so `consume` is a no-op for them.

### finish

```swift
nonisolated func finish() { continuation.finish() }
```

Idempotent and thread-safe. Called by `Worker.deinit` and `ReduxStore.deinit`.

---

## 6. Pipeline Execution

The worker processes one action at a time on the main actor. `runProcess` folds the
middlewares around a `reduceChain` seed, threading a single-shot `terminal` to every settle
point.

```swift
@MainActor
private func runMiddleware(_ action: A, _ terminal: SnapshotTerminal<S>?) {
  let dispatch: @Sendable (A) -> Void = { [weak self] a in self?.dispatch(a) }
  let seed: @MainActor (A) -> Void = { [weak self] a in self?.reduceChain(a, terminal) }

  guard !middlewares.isEmpty else { seed(action); return }

  let chain = middlewares.reversed().reduce(seed) { next, middleware in
    { [weak self] a in
      guard let self else { return }
      let context = MiddlewareContext(self.state, dispatch: dispatch, action: a,
                                      register: …, unregister: …)
      let exit: MiddlewareExit<S, A>
      do { exit = try middleware.run(context) }
      catch { self.resolveChain(error, a, origin: middleware.id, terminal); return }
      // … switch on exit (Section 7)
    }
  }
  chain(action)
}
```

The array is folded **reversed**, so the first middleware in declaration order is the
outermost wrapper and runs first. `reduceChain` is the seed (innermost step).

---

## 7. Middleware Chain

Per-middleware handling of `MiddlewareExit`:

| Exit | Action taken | Logged |
|---|---|---|
| `.next` | emit log; `next(a)` | yes |
| `.defaultNext` | `next(a)` ("not mine") | no |
| `.nextAs(newAction)` | emit log; `next(newAction)` | yes |
| `.exit(.reduce)` | emit; `reduceChain(a, terminal)` | yes |
| `.exit(.reduceAs(newAction))` | emit; `reduceChain(newAction, terminal)` | yes |
| `.exit(.resolve(error))` | emit; `resolveChain(error, a, origin: id, terminal)` | yes |
| `.exit(.done)` | emit; `terminal?(.success(state.readOnly))`; return | yes |
| `.task(body)` | `runTask(body, a, origin: id)`; `next(a)` | at completion |
| `.deferred(handler)` | `runDeferredTask(handler, next, a, origin: id, terminal)` | at completion |
| `throw` | `resolveChain(error, a, origin: id, terminal)` | (via resolver) |

`MiddlewareExitTarget` groups the leave-the-chain destinations (`.reduce`, `.reduceAs`,
`.resolve`, `.done`). `.next`/`.defaultNext`/`.nextAs` stay in the chain; `.task` continues
the chain immediately (the effect runs alongside); `.deferred` suspends the synchronous
chain until its child task resumes.

---

## 8. Reducer Chain

```swift
@MainActor
private func reduceChain(_ action: A, _ terminal: SnapshotTerminal<S>? = nil) {
  runReducers(action)
  evaluateSubscriptions()
  evaluateStreams()
  terminal?(.success(state.readOnly))
}

@MainActor
private func runReducers(_ action: A) {
  for reducer in reducers {
    let context = ReduxReducerContext(state, action)
    let exit = measuring({ exit, dur in .reducer(id: reducer.id, action: action, duration: dur, exit: exit) }) {
      reducer.reduce(context)
    }
    switch exit {
    case .next, .defaultNext: continue
    case .done:               return
    }
  }
}
```

- Reducers run in **forward** (declaration) order.
- `.next` and `.defaultNext` continue; `.done` stops the loop early.
- `measuring` wraps `reduce`, so the worker logs a `.reducer` event for **every** exit (including `.defaultNext`) whenever a handler is attached — unlike middleware and resolver, whose switches skip `.defaultNext`. (The `ReduxReducerExit.defaultNext` doc comment still reads "not logged"; the implementation logs it.)
- After the reducers: subscriptions (Section 11) and snapshot streams (Section 13) are evaluated, then the single-shot terminal fires once on the settled projection.

The `ReduxReducerContext` carries the live (reference) `state`, so mutations by one reducer
are visible to the next.

---

## 9. Resolver Chain

```swift
@MainActor
private func resolveChain(_ error: SendableError, _ action: A, origin: ReduxOrigin,
                          _ terminal: SnapshotTerminal<S>? = nil) {
  let fail: @MainActor (SendableError, A) -> Void = { [weak self] e, a in
    self?.emit(.resolver(id: "default", action: a, duration: .zero, exit: .exit(.fail(e)), error: e))
    terminal?(.failure(e))                         // unhandled → fail the single-shot
  }

  guard !resolvers.isEmpty else { fail(error, action); return }

  let chain = resolvers.reversed().reduce(fail) { next, resolver in
    { [weak self] e, a in
      guard let self else { return }
      let context = ResolverContext(self.state, action: a, error: e, origin: origin,
                                    dispatch: { [weak self] new in self?.dispatch(new) })
      let exit = resolver.run(context)
      switch exit {
      case .defaultNext: next(e, a)                // "not mine" → next resolver
      case .exit(let target):
        self.emit(.resolver(id: resolver.id, action: a, duration: …, exit: exit, error: e))
        switch target {
        case .reduce:                  self.reduceChain(a, terminal)
        case .reduceAs(let newAction): self.reduceChain(newAction, terminal)
        case .fail(let resolved):      terminal?(.failure(resolved)); return
        case .done:                    terminal?(.success(self.state.readOnly)); return
        }
      }
    }
  }
  chain(error, action)
}
```

The seed (`fail`) is the chain terminal: if no resolver handles the error, it logs a
`resolver` event with id `"default"` and fails the single-shot terminal. No developer-side
default resolver is required. Resolvers fold reversed (first in declaration order runs
first), like middleware.

---

## 10. Async Effects

Effects are tracked in `childTasks: [UUID: Task]` and cancelled in `Worker.deinit`. Both run
on the **main actor** — the body reads the `@MainActor` `S.ReadOnly`; `await` points free the
main actor for I/O.

### runTask — fire-and-forget

```swift
@MainActor
private func runTask(_ body: @escaping TaskHandler<S>, _ action: A, origin: ReduxOrigin) {
  let id = UUID()
  let task = Task { @MainActor [weak self] in
    defer { self?.childTasks[id] = nil }
    guard let ro = self?.state.readOnly else { return }
    do    { try await body(ro) }
    catch { self?.resolveChain(error, action, origin: origin) }
  }
  childTasks[id] = task
}
```

The synchronous chain already continued (`next(a)`), so a `.task` does not suspend the
pipeline. A throw routes to the resolver with no terminal (a fire-and-forget effect carries
no snapshot).

### runDeferredTask — suspend & resume

```swift
@MainActor
private func runDeferredTask(_ handler: @escaping DeferredTaskHandler<S, A>,
                             _ next: @escaping @MainActor (A) -> Void,
                             _ action: A, origin: ReduxOrigin,
                             _ terminal: SnapshotTerminal<S>?) {
  let id = UUID()
  let task = Task { @MainActor [weak self] in
    defer { self?.childTasks[id] = nil }
    guard let ro = self?.state.readOnly else { terminal?(.failure(ReduxError.cancelled)); return }
    do {
      let resume = try await handler(ro)
      guard let self else { terminal?(.failure(ReduxError.cancelled)); return }
      switch resume {
      case .next:                  next(action)
      case .nextAs(let newAction): next(newAction)
      case .exit(let target):
        switch target {
        case .reduce:                  self.reduceChain(action, terminal)
        case .reduceAs(let newAction): self.reduceChain(newAction, terminal)
        case .resolve(let error):      self.resolveChain(error, action, origin: origin, terminal)
        case .done:                    terminal?(.success(self.state.readOnly))
        }
      }
    } catch {
      guard let self else { terminal?(.failure(ReduxError.cancelled)); return }
      self.resolveChain(error, action, origin: origin, terminal)
    }
  }
  childTasks[id] = task
}
```

The `terminal` is threaded through so the caller of `dispatch(_:snapshot:)` sees the
post-resume state. If the worker dies before the task resumes, the terminal fails with
`ReduxError.cancelled`.

> **Ordering note.** Because a `.deferred` effect resolves on a child task while the worker
> goes on draining the queue, a later action can reach its reduce terminal before the
> deferred one resumes. The synchronous pipeline segments are FIFO; resumed work is not.
> Order it by `dispatch`ing a follow-up action instead of resuming straight into reduce.

---

## 11. Subscriptions

State→Action reactions registered by middleware, evaluated after each reduce.

```swift
public struct Subscription<S, A>: Sendable, Identifiable {
  public let id: String
  public let origin: A            // the action that registered it (tracing)
  public let registeredBy: String // middleware id (tracing)
  public let when: SubscriptionPredicate<S>
  public let then: SubscriptionHandler<S, A>
}
```

Stored in `subscriptions: [String: Subscription<S, A>]` (keyed by id — registering the same
id replaces the entry). There is **no generation** — lifecycle is purely by id.

### Registration

`MiddlewareContext.subscribe(id:when:then:)` calls the worker-provided `register` hook:

```swift
@MainActor
private func registerSubscription(id:, origin:, registeredBy:, when:, then:) {
  subscriptions[id] = Subscription(...)
  emit(.subscription(.subscribed(...)))
}
```

`unsubscribe(id:)` removes it and emits `.unsubscribed`.

### Evaluation

```swift
@MainActor
private func evaluateSubscriptions() {
  guard !subscriptions.isEmpty else { return }
  let readOnly = state.readOnly
  for subscription in subscriptions.values where subscription.when(readOnly) {
    let action = subscription.then(readOnly)
    emit(.subscription(.executed(...)))
    dispatch(action)                       // new FIFO entry
  }
}
```

Subscriptions are **not** one-shot: each fires every time its predicate holds on a reduce
terminal. The reaction enters the pipeline as a standard dispatch (producing its own logs).
Removing them is the developer's responsibility (`unsubscribe`).

---

## 12. Snapshot API

Single-shot: dispatch an action and `await` a JSON-encoded projection at its terminal.

```swift
nonisolated
public func dispatch<T>(_ action: A, snapshot: T.Type) async -> ReduxEncodedSnapshot
where T: ReduxStateSnapshot<S> {
  await withCheckedContinuation { continuation in
    let request: SnapshotRequest<S> = (
      continuation: continuation,
      capture: { readOnly, encoder in try encoder.encode(T(state: readOnly)) }
    )
    worker.dispatch(action, snapshot: request)
  }
}
```

```swift
public typealias SnapshotRequest<S: ReduxState> =
  ( continuation: CheckedContinuation<ReduxEncodedSnapshot, Never>,
    capture: @MainActor @Sendable (S.ReadOnly, JSONEncoder) throws -> Data )

public typealias SnapshotTerminal<S: ReduxState> =
  @MainActor (Result<S.ReadOnly, SendableError>) -> Void
```

- The action goes through the **same FIFO queue** as `dispatch(_:)`, always `.none` rate — a request/response is never rate-limited.
- The `SnapshotRequest` rides the `TaggedActionEvent` to the worker, which builds the once-only `SnapshotTerminal` via `makeTerminal`.
- The terminal fires at the action's settle point: end of the reducer chain, `.exit(.done)`, or a resolver outcome. `.success` → encode with the **shared** `JSONEncoder` and resume `.success(Data)` (or `.failure` on encode error); `.failure` → resume `.failure`.
- On enqueue rejection (e.g. `.terminated`) the continuation is resolved immediately, so the caller never hangs. Store teardown before settle yields `ReduxError.cancelled`.

Terminal points for the single-shot terminal:

| Terminal | Argument |
|---|---|
| reducer chain end | `.success(readOnly)` |
| middleware `.exit(.done)` | `.success(readOnly)` |
| resolver `.exit(.done)` | `.success(readOnly)` |
| resolver `.exit(.reduce/.reduceAs)` | `.success(readOnly)` (after reduce) |
| resolver `.exit(.fail(e))` / unhandled | `.failure(e)` |
| deferred resume `.exit(.done)` | `.success(readOnly)` |
| enqueue rejection | `.failure(ReduxError…)` |
| store teardown mid-flight | `.failure(ReduxError.cancelled)` |

---

## 13. Streaming Snapshots

The streaming overload returns a bounded `AsyncStream` of encoded snapshots emitted when an
edge-trigger key changes at a reduce terminal.

```swift
nonisolated
public func dispatch(_ action: A, snapshot spec: SnapshotSpec<S>)
  -> AsyncStream<ReduxEncodedSnapshot>
```

### SnapshotSpec

```swift
public struct SnapshotSpec<S>: Sendable where S: ReduxState {
  public enum Limit: Sendable {
    case count(UInt)                 // first N successfully-encoded frames
    case time(Duration)
    case timeOrCount(Duration, UInt) // whichever first
  }
  let trigger:     @MainActor @Sendable (S.ReadOnly) -> AnyHashable   // K erased
  let encode:      @MainActor @Sendable (S.ReadOnly, JSONEncoder) throws -> Data  // T erased
  let emitInitial: Bool
  let limit:       Limit
}
```

- The snapshot type `T` and key type `K` are erased at construction (baked into `encode`/`trigger`), so the spec is generic only over `S`.
- A second initializer takes a `build:` closure for snapshot shapes needing call-site context.
- A zero count bound asserts in debug and finishes immediately in release.

### Streams registry & StreamEntry

```swift
@MainActor final class Streams {
  private(set) var entries: [StreamEntry] = []
  func register(_:) ; func unregister(id:) -> Bool ; func finishAll()
}
```

`Streams` is a Worker **property** (not a build-local), so `deinit` can eagerly finish every
active stream. `StreamEntry` is a mutable `@MainActor` class with a **`nonisolated init`**
(constructible from the nonisolated stream `dispatch` body; `Sendable` by `@MainActor`
isolation):

- `lastKey: AnyHashable?` — the edge-trigger cursor.
- `remaining: UInt?` — count bound; `nil` = time-only.
- `encode` takes the worker's **shared** encoder as an argument (no per-entry allocation).
- `yield` / `finish` — the continuation endpoints.

`tick(_:encoder:)` returns a `TickOutcome`: `.unchanged`, `.frame(byteCount:)`,
`.encodeFailed(error)` (yields `.failure`, stays alive, does not decrement the count — one
bad reading must not kill a live feed; the cursor still advances), or `.finished(byteCount:)`
(count exhausted → remove). The worker's `logTick` maps each outcome to a `.snapshot(...)`
log so `StreamEntry` stays free of `onLog`.

### evaluateStreams

```swift
@MainActor
private func evaluateStreams() {
  guard !streams.entries.isEmpty else { return }
  let readOnly = state.readOnly
  var finished: [String] = []
  for entry in streams.entries {
    if logTick(entry, entry.tick(readOnly, encoder: encoder)) { finished.append(entry.id) }
  }
  for id in finished { streams.unregister(id: id) }
}
```

Called inside `reduceChain` after `evaluateSubscriptions()` — the sole periodic stream hook
(state only changes at a reduce terminal). Zero-cost when no stream is registered.

### Registration & lifecycle

The stream overload registers the entry **and then** arms the action in the same main-actor
turn — closing the race between registration and the arming action's reduce terminal. With
`emitInitial`, the current state is emitted at registration (and the entry removed if that
first frame already exhausts it); otherwise the cursor is primed so only subsequent changes
emit.

Termination sources, each finishing the stream exactly once (the one that removes the entry
logs the reason):

| Source | Mechanism | `StreamFinishReason` |
|---|---|---|
| count exhausted | `tick` → `.finished` → `evaluateStreams` removes | `.limitReached` |
| time elapsed | a time `Task` unregisters + `noteStreamFinished` | `.limitReached` |
| consumer cancel | `continuation.onTermination` unregisters | `.consumerCancelled` |
| arming rejected | the arming `dispatch` failed → yield `.failure`, unregister | `.armingRejected` |
| store `deinit` | `finishAllStreams()` via the main-actor hop | `.storeTerminated` |

`yield`/`finish` after `finish()` are documented `AsyncStream` no-ops, so races between
sources are harmless.

---

## 14. Rate Control & Backpressure Diagnostics

The dispatcher buffer is **unbounded** — logical actions are never silently dropped, keeping
the action history deterministic and replayable. Two orthogonal mechanisms manage load.

### DispatchRateLimit (opt-in admission gate)

```swift
public enum DispatchRateLimit: Sendable {
  case none                 // default: unbounded, never dropped (lock-free)
  case limit(Int)           // ≤ N actions with the same id pending (un-reduced); drops the NEW one
  case throttle(Duration)   // ≤ one per id per window (leading edge); drops within the window
}
```

For high-frequency **sample-stream** sources (AR frames, sensors). Gating happens in
`Dispatcher.tryEnqueue` under a small `Mutex<RateState>`; a drop returns
`ReduxError.rateLimited` and is logged. `.limit` slots are released by `consume(id:counted:)`
after the worker reduces the action — so `.limit` is a queue-depth gate, effective only when
the reduce loop is the bottleneck. `.throttle` is a time gate (caps the dispatch rate).

### Backpressure diagnostics (no drop)

```swift
public struct StoreOptions: Sendable {
  public var pressureWindow: Duration     // .seconds(1)
  public var pressureThreshold: Int       // 120 (clamped ≥ 1)
  public var pressureCooldown: Duration   // .seconds(5) (anti-spam)
}
```

`Worker.trackPressure(id:)` keeps a per-id sliding window of reduce timestamps; when an id
exceeds the threshold within the window it emits `.highFrequencyAction(id:count:window:)`,
respecting the cooldown. This runs **only when a log handler is attached** — pure
diagnostics, no drop.

### ReduxError

```swift
public enum ReduxError: Error, Sendable {
  case terminated   // dispatcher stream ended at enqueue time
  case rateLimited  // a DispatchRateLimit dropped this action at the gate
  case cancelled    // pending snapshot abandoned — store torn down before settle
}
```

---

## 15. Modules, Maps & Slices

### ReduxModuleMap

```swift
public struct ReduxModuleMap<LS, LA, S, A>: Sendable {
  let toState:      @MainActor @Sendable (S) -> LS    // global state → live local state
  let toAction:     @Sendable (A) -> LA?              // global action → local (nil = not mine)
  let toRootAction: @Sendable (LA) -> A               // local action → global (dispatch path)
}
```

Composition-time descriptor that plugs a module's `LS`/`LA` into the central `S`/`A`. The
**same value** drives both the reducer lift and the store slice, so projection/extract are
written once.

```swift
static func linear(state: KeyPath<S, LS>, action: KeyPath<A, LA?> & Sendable,
                   toRootAction: @escaping @Sendable (LA) -> A) -> Self
static func scattered(state: @escaping @MainActor @Sendable (S) -> LS,
                      action: KeyPath<A, LA?> & Sendable,
                      toRootAction: @escaping @Sendable (LA) -> A) -> Self
```

- **Linear** — `LS` is a contiguous sub-object of `S` (a key path) and `LA` a single case of `A`. The module state is `@ReduxState` (owns its storage), nested in the root.
- **Scattered** — `LS` is a `@ReduxMappedState` built field-by-field from per-field `ReduxBinding`s over split, app-owned leaves of `S`.

### Lifts

`AnyReduxReducer`, `AnyMiddleware`, and `AnyResolver` each take a `moduleMap:` init that
lifts a local component into the central space. `toAction` selects the local action
(`nil` → `.defaultNext`); `toState` projects the live local state; `toRootAction` re-embeds
dispatched / redirected / resumed actions. `AnyReduxReducer` also has the explicit
`init(_:toState:toAction:)` form (linear).

For middleware, the lifted effect bodies read the projected local `readOnly`, and
`MiddlewareExit`/`MiddlewareResumeExit`/`MiddlewareExitTarget` are mapped local→global
(actions re-embedded via `toRootAction`). Registered subscriptions' predicate/handler read
the captured local state and re-embed their origin/result.

### ReduxStoreSlice & slice(_:)

```swift
@MainActor
public final class ReduxStoreSlice<LS, LA>: ReduxModule {
  private let read: @MainActor @Sendable () -> LS.ReadOnly
  private let send: @Sendable (LA) -> Void
  public var state: LS.ReadOnly { read() }
  nonisolated public func dispatch(_ actions: LA...) { actions.forEach(send) }
}
```

```swift
@MainActor
func slice<LS, LA>(state toState: @MainActor @Sendable (S) -> LS,
                   action toRootAction: @escaping @Sendable (LA) -> A) -> ReduxStoreSlice<LS, LA> {
  let local = toState(_state)                       // projected ONCE, retained by the slice
  return ReduxStoreSlice(read: { local.readOnly },
                         send: { la in self.dispatch(toRootAction(la)) })
}
```

The local state is projected once and retained: a mapped state's `ReadOnly` references it
`unowned`, so a per-read rebuild would dangle. Reads still observe the live root because the
projection forwards to the root leaves (linear: the live sub-object; scattered: the
`ReduxBinding` targets). Overloads accept a `ReduxModuleMap`, an explicit projection +
`toRootAction`, or a `KeyPath` (linear convenience).

### ReduxBinding

```swift
public struct ReduxBinding<V>: Sendable {
  public init(get: @escaping @MainActor @Sendable () -> V,
              set: @escaping @MainActor @Sendable (V) -> Void)
  @MainActor public var value: V { get nonmutating set }
}
```

A `Sendable`, UI-agnostic get/set projection with **no** SwiftUI graph/transaction
machinery — its `set` writes straight through. Used internally to back a mapped state's
projected properties (never handed to a View; Views mutate via `dispatch`).
`.constant(_:)` (ignores writes) and `.projected(_:)` (backed by an internal `@Observable`
`ReduxBindingValue`) support previews and tests without a root.

---

## 16. Logging

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

```swift
public enum SubscriptionLog<A>: Sendable {
  case subscribed(registeredBy: String, id: String, origin: A, duration: Duration)
  case executed(registeredBy: String, id: String, origin: A, duration: Duration, action: A)
  case unsubscribed(registeredBy: String, id: String, duration: Duration)
}

public enum SnapshotLog<A>: Sendable {
  case resolved(action: A, byteCount: Int, duration: Duration)
  case failed(action: A, error: SendableError)
  case streamRegistered(id: String, action: A, emitInitial: Bool)
  case streamFrame(id: String, byteCount: Int)
  case streamEncodeFailed(id: String, error: SendableError)
  case streamFinished(id: String, reason: StreamFinishReason)
}

public enum StreamFinishReason: Sendable {
  case limitReached, consumerCancelled, storeTerminated, armingRejected
}
```

### Zero-cost gating

```swift
@inline(__always) func emit(_ event: @autoclosure () -> ReduxLog<S, A>) {
  guard let onLog else { return }
  onLog(event())
}

@inline(__always) func measuring<R>(_ make: (R, Duration) -> ReduxLog<S, A>, _ body: () -> R) -> R {
  guard let onLog else { return body() }
  let start = ContinuousClock.now
  let result = body()
  onLog(make(result, .now - start))
  return result
}
```

When `onLog == nil` nothing is built and no clock is read. `.defaultNext` from middleware and
resolver is not logged (their switches skip it). The handler is `@Sendable` and owns its own
thread-safety.

---

## 17. Type Aliases

### Public

| Alias | Signature |
|---|---|
| `ReduxOrigin` | `String` |
| `SendableError` | `any Error & Sendable` |
| `ReduxEncodedSnapshot` | `Result<Data, Error>` |
| `ReduxLogHandler<S, A>` | `@Sendable (ReduxLog<S, A>) -> Void` |
| `MiddlewareHandler<S, A>` | `@MainActor (MiddlewareContext<S, A>) throws -> MiddlewareExit<S, A>` |
| `ReduxReduceHandler<S, A>` | `@MainActor (ReduxReducerContext<S, A>) -> ReduxReducerExit` |
| `ResolveHandler<S, A>` | `@MainActor (ResolverContext<S, A>) -> ResolverExit<A>` |
| `TaskHandler<S>` | `@MainActor @Sendable (S.ReadOnly) async throws -> Void` |
| `DeferredTaskHandler<S, A>` | `@MainActor @Sendable (S.ReadOnly) async throws -> MiddlewareResumeExit<A>` |
| `SubscriptionPredicate<S>` | `@MainActor @Sendable (S.ReadOnly) -> Bool` |
| `SubscriptionHandler<S, A>` | `@MainActor @Sendable (S.ReadOnly) -> A` |

### Internal

| Alias | Signature |
|---|---|
| `RegisterSubscription<S, A>` | `@MainActor @Sendable (String, A, @escaping SubscriptionPredicate<S>, @escaping SubscriptionHandler<S, A>) -> Void` |
| `UnregisterSubscription` | `@MainActor @Sendable (String) -> Void` |
| `SnapshotRequest<S>` | `(continuation: CheckedContinuation<ReduxEncodedSnapshot, Never>, capture: @MainActor @Sendable (S.ReadOnly, JSONEncoder) throws -> Data)` |
| `SnapshotTerminal<S>` | `@MainActor (Result<S.ReadOnly, SendableError>) -> Void` |
| `TaggedActionEvent` | `(action: A, counted: Bool, onTerminal: SnapshotRequest<S>?)` |

---

## 18. Macros

The macro target is `TinyReduxMacros` (built with SwiftSyntax / SwiftSyntaxMacros /
SwiftCompilerPlugin). Plugin registers `ReduxStateMacro`, `ReduxMappedStateMacro`,
`ReduxBindingBackedMacro`, `ReduxActionMacro`.

### 18.1 @ReduxState

```swift
@attached(member, names: named(ReadOnly), named(readOnly), named(init))
public macro ReduxState() = #externalMacro(module: "TinyReduxMacros", type: "ReduxStateMacro")
```

For an **owned, value-backed** state (root or `.linear` module). Diagnoses on non-classes.
Generates:

1. `@Observable @MainActor final class ReadOnly: ReduxReadOnlyState, Sendable` — `private unowned let state`, a `nonisolated init`, and a get-only forwarder for each stored `var` not marked `@ObservationIgnored`.
2. `@ObservationIgnored lazy var readOnly = ReadOnly(self)`.
3. A designated `nonisolated init(<field>: T, …)` assigning `self._<field>`.

Generated members are `public` when the class is `public`/`open`. The class must declare
`: ReduxState` **and** `@Observable` (and typically `@MainActor`) explicitly. Stored `var`s
stay stored and remain the real `@Observable` storage.

### 18.2 @ReduxMappedState

```swift
@attached(member, names: named(ReadOnly), named(readOnly), named(init))
@attached(memberAttribute)
@attached(extension, conformances: Observable)
public macro ReduxMappedState() = #externalMacro(module: "TinyReduxMacros", type: "ReduxMappedStateMacro")
```

For a **flat, app-independent** module state projected onto a root via `ReduxBinding`
(`.scattered`). Roles:

- **member**: `ReadOnly`, `readOnly`, and the designated `init(<field>: ReduxBinding<T>, …)`.
- **memberAttribute**: attaches `@ReduxBindingBacked` to each stored `var`.
- **extension**: adds the `Observable` marker conformance.

The class must declare `: ReduxMappedState` and `@MainActor` and must **not** also be
`@Observable` (fields become computed; observability rides the binding target).

### 18.3 @ReduxBindingBacked

```swift
@attached(accessor)
@attached(peer, names: prefixed(_))
public macro ReduxBindingBacked() = #externalMacro(...)
```

Applied by `@ReduxMappedState` to each stored `var`. Turns `var x: T` into a computed
forwarder over a `ReduxBinding<T>` backing:

- accessor: `get { _x.value }` / `set { _x.value = newValue }`
- peer: `private let _x: ReduxBinding<T>`

### 18.4 @ReduxAction

```swift
@attached(member, names: named(id))
public macro ReduxAction() = #externalMacro(module: "TinyReduxMacros", type: "ReduxActionMacro")
```

For an action `enum`. Diagnoses on non-enums. Synthesizes:

```swift
public var id: String {
  switch self { case .<name>: return "<name>" /* … */ }
}
```

Associated values are ignored, matching the protocol's case-only identity.

---

## 19. Concurrency Model

### MainActor pipeline

The whole pipeline — `runMiddleware`, `reduceChain`, `runReducers`, `resolveChain`,
`evaluateSubscriptions`, `evaluateStreams`, and all component `run`/`reduce` calls — runs on
`@MainActor`. The contexts (`MiddlewareContext`, `ReduxReducerContext`, `ResolverContext`)
carry the live state on the main actor. `.task` / `.deferred` bodies are `@MainActor` too;
`await` points free the main actor for I/O.

### Nonisolated boundaries

| Point | Isolation | Reason |
|---|---|---|
| `ReduxStore.dispatch(...)` | `nonisolated` | callable from any isolation |
| `Worker.dispatch(...)` | `nonisolated` | dispatch entry point |
| `Dispatcher.tryEnqueue / consume / finish` | `nonisolated` | thread-safe (Mutex / yield) |
| `MiddlewareContext.dispatch` / `ResolverContext.dispatch` | `@Sendable` closures | thread-safe |
| `ReduxStoreSlice.dispatch` | `nonisolated` | forwards to the root dispatch |

### Mutex usage

`Mutex<RateState>` (from `Synchronization`) guards **only** the rate-control maps (`counts`
for `.limit`, `lastTime` for `.throttle`). The `.none` path never takes the lock — the
continuation's `yield` is already thread-safe. The lock is never held across the `yield`.

### Sendable

`ReduxStore`, `Worker`, `Dispatcher`, `ReduxAction`, `ReduxState`, all exit enums,
`DispatchRateLimit`, `ReduxError`, `StoreOptions`, `TaggedActionEvent`, `SnapshotRequest`,
and `ReduxLog` are `Sendable` — they cross isolation boundaries or travel in the stream.

---

## 20. Error Flow

| Source | Routing |
|---|---|
| middleware `throw` | `catch → resolveChain(error, a, origin: middleware.id, terminal)` |
| middleware `.exit(.resolve(e))` | `resolveChain(e, a, origin: middleware.id, terminal)` |
| `.task` body throws | `resolveChain(error, action, origin)` (no terminal — fire-and-forget) |
| `.deferred` body throws / `.exit(.resolve)` | `resolveChain(error, action, origin, terminal)` |
| resolver `.exit(.fail(e))` | `terminal?(.failure(e))` |
| no resolver handles it | seed `fail`: log `resolver "default" .exit(.fail(e))`; `terminal?(.failure(e))` |

`origin` is the middleware id that raised the error (tracing, surfaced in
`ResolverContext.origin`). A fire-and-forget `.task` carries no snapshot terminal, so its
resolver branch passes `nil`; `.deferred` preserves the original terminal.

---

## 21. Memory Management

### No retain cycles in the pipeline

`runMiddleware`, the `dispatch`/`seed` closures, the effect tasks, and the terminal all
capture `self` **weakly** (`[weak self]`) and bail when it is gone. The worker loop task is
`Task { @MainActor [weak self] … }`. There is no strong self-capture keeping the store alive
through the pipeline.

### Ownership

```
ReduxStore
├── _state: S          (strong, @MainActor)
└── worker: Worker     (strong, let)
      ├── state: S     (strong, @MainActor — same object as _state)
      └── dispatcher   (strong, let)
```

`ReduxStore.deinit` finishes the dispatcher (ending the loop) and hops to the main actor to
finish active streams. `Worker.deinit` finishes the dispatcher and cancels all `childTasks`.

### ReadOnly — unowned

The macro-generated `ReadOnly` holds `private unowned let state` (not `weak`): it is created
as a `lazy var` of the state, so the owner guarantees its lifetime. Subscription
predicates/handlers and snapshot captures read through `readOnly`, so they do not extend the
state's lifetime.

### Slices

`ReduxStoreSlice` retains the **projected** local state (projected once at `slice(...)`).
For a mapped state, its `ReadOnly` references that retained instance `unowned`, so the slice
must keep the projection alive — which it does. The `send` closure captures the store via
the dispatch path.

### Streams

`Streams` is a `@MainActor` Worker property; entries hold the continuation's `yield`/`finish`
endpoints. `continuation.onTermination` retains nothing of the worker beyond the unregister
hop, and `deinit` finishes every entry so consumers' `for await` loops end and no entry
leaks.
