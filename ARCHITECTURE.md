# TinyRedux — Technical Specifications

|              |                                     |
|--------------|-------------------------------------|
| **Version**  | 14.1.0                              |
| **Platform** | iOS 18+, macOS 15+                  |
| **Swift**    | 6.0 (Strict Concurrency)            |

---

## Table of Contents

1. [Architectural Overview](#1-architectural-overview)
2. [Protocols](#2-protocols)
3. [Store](#3-store)
4. [Worker](#4-worker)
5. [Dispatcher](#5-dispatcher)
6. [Pipeline Construction](#6-pipeline-construction)
7. [Middleware Chain](#7-middleware-chain)
8. [Reducer Chain](#8-reducer-chain)
9. [Resolver Chain](#9-resolver-chain)
10. [Async Paths](#10-async-paths)
11. [Subscriptions](#11-subscriptions)
12. [Snapshot API](#12-snapshot-api)
13. [Capacity & Admission Control](#13-capacity--admission-control)
14. [Generation Tracking](#14-generation-tracking)
15. [Suspend/Resume](#15-suspendresume)
16. [Logging](#16-logging)
17. [Type Aliases](#17-type-aliases)
18. [Macros](#18-macros)
19. [Concurrency Model](#19-concurrency-model)
20. [Error Flow](#20-error-flow)
21. [Memory Management](#21-memory-management)

---

## 1. Architectural Overview

TinyRedux implements the **Supervised Redux** model — a unidirectional data flow where middleware, reducer, and resolver cooperate in a serialized dispatch pipeline.

### Component Hierarchy

```
Store<S, A> [@MainActor, @Observable, @dynamicMemberLookup, Sendable]
├── _state: S                             [@ObservationIgnored, @MainActor, internal]
└── worker: Worker                        [let, Sendable]
      ├── dispatcher: Dispatcher          [nonisolated let, Sendable]
      │     ├── stream: AsyncStream       [.unbounded, consumed by for-await]
      │     ├── continuation: Continuation[Sendable, thread-safe]
      │     ├── capacity: Int             [let, from StoreOptions.dispatcherCapacity]
      │     └── mutex: Mutex<MutableState>[generation + counts + pendingCount + isTerminated + isSuspended]
      ├── middlewares: [AnyMiddleware]     [let, reversed at init, immutable]
      ├── reducers: [AnyReducer]          [let, forward order, immutable]
      ├── resolvers: [AnyResolver]        [let, reversed at init, immutable]
      ├── onLog: LogHandler?              [nonisolated let, captured at build-time]
      ├── process: ProcessHandler?        [var, @MainActor, built once at init]
      ├── task: Task<Void, Never>?        [var, @MainActor, for-await loop]
      └── state: S                        [var, @MainActor, owned directly]
```

### General Flow

```
Caller (any isolation)
    │
    ▼
Store.dispatch()          [nonisolated]
    │
    ▼
Worker.dispatch()         [nonisolated]
    │
    ▼
Dispatcher.tryEnqueue()   [nonisolated, Mutex-protected]
    │
    ▼
AsyncStream buffer        [.unbounded transport]
    │
    ▼
Worker for-await loop     [@MainActor]
    │
    ▼
process?(readOnly, action, deferSnapshot)    [@MainActor]
    │
    ├── middlewareChain    [fold, reversed]
    │     └── per middleware → MiddlewareExit
    │
    ├── reduceChain        [forward iteration]
    │     └── per reducer → ReducerExit
    │     └── subscriptionChain → evaluates entries
    │
    └── resolveChain       [fold, reversed, only on error]
          └── per resolver → ResolverExit
```

---

## 2. Protocols

### 2.1. ReduxState

```swift
@MainActor
public protocol ReduxState: AnyObject, Observable, Sendable {
  associatedtype ReadOnly: ReduxReadOnlyState where ReadOnly.State == Self
  var readOnly: ReadOnly { get }
}
```

**Constraints**:
- `@MainActor`: the state lives on the main actor; all mutations happen there.
- `AnyObject`: reference type. The reducer mutates properties in place (no copies).
- `Observable`: `@Observable` macro for SwiftUI integration via observation tracking.
- `Sendable`: required because the `Store` crosses isolation boundaries.

**Associated type**:
- `ReadOnly`: read-only projection of the state. The `ReadOnly.State == Self` constraint ensures bidirectional correspondence.

**Contract**:
- `readOnly` must return a projection that reflects every observable property of the state without exposing setters.
- The `@ReduxState` macro generates `ReadOnly` as a nested class with get-only computed properties that read from the state via `unowned let state`.

### 2.2. ReduxReadOnlyState

```swift
@MainActor
public protocol ReduxReadOnlyState: AnyObject, Observable, Sendable {
  associatedtype State: ReduxState
  init(_ state: State)
}
```

**Constraints**: same as `ReduxState` (`@MainActor`, `AnyObject`, `Observable`, `Sendable`).

**Associated type**:
- `State`: the mutable state type of which this class is a projection.

**Contract**:
- `init(_:)` accepts the mutable state and creates the projection.
- The projection's properties must be get-only computed properties that delegate to the original state.
- The instance is created only once (lazily) via `readOnly` and stored in the state.

### 2.3. ReduxAction

```swift
public protocol ReduxAction: CustomStringConvertible, Identifiable, Equatable, Sendable {
  var id: String { get }
  @MainActor var debugString: String { get }
}
```

**Constraints**:
- `CustomStringConvertible`: `description` (nonisolated). Default: `id`.
- `Identifiable`: `id` groups actions for rate limiting and logging.
- `Equatable`: default implementation compares `id`. Override for full semantics.
- `Sendable`: crosses nonisolated → MainActor boundary.

**Properties**:
- `id: String` — stable identifier derived from the enum case name. Used by `Dispatcher.tryEnqueue` for rate limiting (`counts[id]`) and by `Dispatcher.consume(id:)` to release slots.
- `debugString: String` (`@MainActor`) — rich representation used by the log handler. Can access associated values that contain `@MainActor` references. Default: `description`.

**Default implementations**:
```swift
extension ReduxAction {
  public var description: String { id }
  @MainActor public var debugString: String { description }
  public static func ==(lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}
```

### 2.4. ReduxStateSnapshot

```swift
public protocol ReduxStateSnapshot<S>: Codable, Sendable {
  associatedtype S: ReduxState
  @MainActor init(state: S.ReadOnly)
}
```

**Constraints**:
- `Codable`: the Worker encodes the instance to `Data` via `JSONEncoder`.
- `Sendable`: the result (`Result<Data, Error>`) crosses isolation boundaries.

**Contract**:
- `init(state:)` is `@MainActor` because it accesses `@MainActor` properties of `S.ReadOnly`.
- The capture happens at the pipeline's terminal point, after the reducers have completed.
- The conformer is typically a `struct` that captures a subset of state properties.

### 2.5. Middleware

```swift
public protocol Middleware: Identifiable, Sendable {
  associatedtype S: ReduxState
  associatedtype A: ReduxAction
  var id: String { get }
  @MainActor func run(_ context: MiddlewareContext<S, A>) throws -> MiddlewareExit<S, A>
}
```

**Contract**:
- `run` is `@MainActor`, synchronous. Escaping from MainActor happens via `.task` (fire-and-forget) or `.deferred` (async with resume).
- `throws`: a throw is caught by the pipeline and routed to the resolver chain.
- The return type `MiddlewareExit<S, A>` controls the pipeline flow. Each case has specific semantics (see [Section 7](#7-middleware-chain)).
- `id` is used for logging and as the `origin` in errors routed to resolvers.

### 2.6. Reducer

```swift
public protocol Reducer: Identifiable, Sendable {
  associatedtype S: ReduxState
  associatedtype A: ReduxAction
  var id: String { get }
  var reduce: ReduceHandler<S, A> { get }
}
```

**Contract**:
- `reduce` is a stored closure `@MainActor (ReducerContext<S, A>) -> ReducerExit`. It cannot throw.
- The closure must be pure: same inputs → same mutations. No side effects.
- Only synchronous O(1) assignments. Asynchronous or complex logic belongs in middleware.

### 2.7. Resolver

```swift
public protocol Resolver: Identifiable, Sendable {
  associatedtype S: ReduxState
  associatedtype A: ReduxAction
  var id: String { get }
  @MainActor func run(_ context: ResolverContext<S, A>) -> ResolverExit<A>
}
```

**Contract**:
- `run` is `@MainActor`, synchronous, non-throwing. Every error is expressed via `ResolverExit`.
- The resolver can dispatch recovery actions but cannot mutate the state directly.
- `ResolverExit` controls the resolve chain flow (see [Section 9](#9-resolver-chain)).

---

## 3. Store

### Definition

```swift
@Observable
@dynamicMemberLookup
public final class Store<S: ReduxState, A: ReduxAction>: Sendable {
  @ObservationIgnored @MainActor var _state: S
  @ObservationIgnored let worker: Worker
}
```

### Properties

| Property | Type | Isolation | Access | Description |
|---|---|---|---|---|
| `_state` | `S` | `@MainActor` | `internal` | Mutable state. `@ObservationIgnored` because observation happens on `ReadOnly`. |
| `worker` | `Worker` | `let` (Sendable) | `internal` | Executes the pipeline. Safe nonisolated access. |

### Lifecycle

**init**:
```swift
public init(
  initialState state: S,
  middlewares: [AnyMiddleware<S, A>],
  resolvers: [AnyResolver<S, A>],
  reducers: [AnyReducer<S, A>],
  options: StoreOptions = .init(),
  onLog: LogHandler<S, A>? = nil
)
```

1. Assigns `_state = state`.
2. Creates `Worker` with state, components, options, and log handler.
3. The Worker in turn creates the `Dispatcher`, reverses middlewares and resolvers, calls `buildDispatchProcess()`, and starts the loop Task.

**deinit**:
```swift
deinit {
  worker.dispatcher.finish()
}
```

`finish()` terminates the stream (idempotent). The for-await in the Worker exits, the Task completes.

### dynamicMemberLookup

```swift
@MainActor
public subscript<Value>(dynamicMember keyPath: KeyPath<S.ReadOnly, Value>) -> Value {
  state[keyPath: keyPath]
}
```

Allows accessing state properties as if they were Store properties: `store.username` is equivalent to `store.state.username`.

### State access

```swift
@MainActor
public var state: S.ReadOnly {
  _state.readOnly
}
```

Read-only property that returns the `ReadOnly` projection of the state. `@MainActor` because `readOnly` is a lazy var of the state.

---

## 4. Worker

### Definition

```swift
extension Store {
  final class Worker: Sendable {
    nonisolated let dispatcher: Dispatcher
    let middlewares: [AnyMiddleware<S, A>]
    let reducers: [AnyReducer<S, A>]
    let resolvers: [AnyResolver<S, A>]
    nonisolated let onLog: LogHandler<S, A>?

    @MainActor private var process: ProcessHandler<S, A>?
    @MainActor private var task: Task<Void, Never>?
    @MainActor private var state: S
  }
}
```

### Properties

| Property | Type | Isolation | Description |
|---|---|---|---|
| `dispatcher` | `Dispatcher` | `nonisolated let` | Transport + admission control. Sendable. |
| `middlewares` | `[AnyMiddleware<S, A>]` | `let` | Array **reversed** at init. |
| `reducers` | `[AnyReducer<S, A>]` | `let` | Forward order, not reversed. |
| `resolvers` | `[AnyResolver<S, A>]` | `let` | Array **reversed** at init. |
| `onLog` | `LogHandler<S, A>?` | `nonisolated let` | Captured at build-time with optional chaining. |
| `process` | `ProcessHandler<S, A>?` | `@MainActor var` | Pipeline closure, built once. |
| `task` | `Task<Void, Never>?` | `@MainActor var` | Event loop task. |
| `state` | `S` | `@MainActor var` | State owned directly. |

**Reversal**: middlewares and resolvers are reversed (`reversed()`) at init because the fold (`Array.reduce`) applies the last element of the list as the outermost wrapper. The reversal ensures that the first element in the user-supplied array executes first.

### Init

```swift
init(
  initialState state: S,
  middlewares: [AnyMiddleware<S, A>],
  resolvers: [AnyResolver<S, A>],
  reducers: [AnyReducer<S, A>],
  options: StoreOptions = .init(),
  onLog: LogHandler<S, A>? = nil
)
```

1. Assigns state, components (middlewares/resolvers reversed), onLog.
2. Creates `Dispatcher(capacity: options.dispatcherCapacity)`.
3. Captures `dispatcher.events` in a local constant.
4. Starts `Task { @MainActor [weak self] in ... }`:
   - Builds `process = buildDispatchProcess()`.
   - Loop: `for await event in events`.
   - For each event: `defer { dispatcher.consume(id: event.action.id) }`.
   - Generation check: if stale → `onSnapshot?.continuation.resume(returning: .failure(.staleGeneration))`, skip.
   - Cancellation check: if cancelled and has snapshot → resume with `CancellationError()`.
   - Builds `deferSnapshot` handler from the optional `onSnapshot`.
   - Invokes `process?(state.readOnly, event.action, deferSnapshot)`.

### Event Loop

```
for await event in events {
  defer { dispatcher.consume(id: event.action.id) }

  // 1. Generation check
  guard dispatcher.isCurrentGeneration(event.generation) else {
    event.onSnapshot?.continuation.resume(returning: .failure(.staleGeneration))
    continue
  }

  // 2. Cancellation check (only if has snapshot)
  if Task.isCancelled, event.onSnapshot != nil {
    event.onSnapshot!.continuation.resume(returning: .failure(CancellationError()))
    continue
  }

  // 3. Build deferSnapshot handler
  let deferSnapshot: SnapshotHandler<S>? = ...

  // 4. Execute pipeline
  process?(state.readOnly, event.action, deferSnapshot)
}
```

**Invariant**: `consume(id:)` is called in `defer` for **every** event, regardless of generation. This ensures that `pendingCount` is decremented even for stale events.

### Dispatch Entry Points

Two `@Sendable nonisolated` methods:

```swift
func dispatch(maxDispatchable limit: UInt = 0, actions: [A])
```
Fire-and-forget. Iterates over actions, calls `tryEnqueue` for each with `onSnapshot: nil`. On failure (except `.staleGeneration`), emits a log via `Task { @MainActor }`.

```swift
func dispatch(_ action: A, onSnapshot: ReadOnlySnapshot<S>)
```
Single action with snapshot handler. On failure, resumes the continuation with `.failure(error)` and logs (except `.staleGeneration`).

### buildDispatchProcess

Builds the `ProcessHandler<S, A>` closure once. Returns `middlewareChain`. See [Section 6](#6-pipeline-construction).

---

## 5. Dispatcher

### Definition

```swift
extension Store.Worker {
  final class Dispatcher: Sendable {
    // ...
  }
}
```

### Internal Structures

#### TaggedActionEvent

```swift
struct TaggedActionEvent: Sendable {
  let action: A
  let onSnapshot: ReadOnlySnapshot<S>?
  let generation: UInt64
}
```

Element consumed by the Worker loop. Associates an action, optional snapshot handler, and generation at the time of enqueue.

#### MutableState

```swift
private struct MutableState: ~Copyable {
  var generation: UInt64 = 0
  var counts: [String: UInt] = [:]
  var pendingCount: Int = 0
  var isTerminated: Bool = false
  var isSuspended: Bool = false
}
```

State protected by `Mutex`. `~Copyable` for exclusive access enforcement.

| Field | Type | Description |
|---|---|---|
| `generation` | `UInt64` | Counter incremented by `flush()`/`suspend()`. Used to invalidate stale events. |
| `counts` | `[String: UInt]` | Per-action-id counters for rate limiting. Key = `action.id`. |
| `pendingCount` | `Int` | Queued + in-flight actions. Slot released only by `consume(id:)`. |
| `isTerminated` | `Bool` | `true` after `finish()`. No new enqueue accepted. |
| `isSuspended` | `Bool` | `true` after `suspend()`. New enqueues rejected with `.suspended`. |

### Properties

```swift
private let stream: AsyncStream<TaggedActionEvent>
private let continuation: AsyncStream<TaggedActionEvent>.Continuation
private let mutex: Mutex<MutableState>
private let capacity: Int
```

| Property | Description |
|---|---|
| `stream` | `AsyncStream` with `bufferingPolicy: .unbounded`. Transport only, admission control is explicit. |
| `continuation` | Handle for yielding new elements and termination. `Sendable`. |
| `mutex` | `Mutex<MutableState>` (from the `Synchronization` module). Protects concurrent access. |
| `capacity` | Maximum limit for `pendingCount`. From `StoreOptions.dispatcherCapacity`. |

### Init

```swift
init(capacity: Int) {
  var c: AsyncStream<TaggedActionEvent>.Continuation!
  self.stream = AsyncStream<TaggedActionEvent>(bufferingPolicy: .unbounded) { c = $0 }
  self.continuation = c
  self.mutex = Mutex(MutableState())
  self.capacity = capacity
}
```

The stream is created with `bufferingPolicy: .unbounded` because buffering is managed explicitly by the Dispatcher via `pendingCount` and `capacity`.

### tryEnqueue

```swift
@discardableResult
func tryEnqueue(
  id: String,
  limit: UInt,
  generation: UInt64? = nil,
  _ event: ActionEvent<S, A>
) -> Result<Void, EnqueueFailure>
```

**Parameters**:
- `id`: `action.id` for rate limiting.
- `limit`: maximum actions with the same `id` in the queue. `0` = unlimited.
- `generation`: optional. If provided, rejects with `.staleGeneration` if it does not match the current generation. Used by subscriptions to avoid ghost dispatches post-flush.
- `event`: tuple `(action: A, onSnapshot: ReadOnlySnapshot<S>?)`.

**Atomic flow** (single `mutex.withLock`):

```
1. isTerminated?     → .failure(.terminated)
2. isSuspended?      → .failure(.suspended)
3. generation match? → .failure(.staleGeneration) if provided and does not match
4. pendingCount < capacity? → .failure(.bufferLimitReached)
5. limit > 0 && counts[id] >= limit? → .failure(.maxDispatchableReached)
6. pendingCount += 1
7. counts[id] += 1 (if limit > 0)
8. capture current generation
```

After the lock, if `success`: `continuation.yield(TaggedActionEvent(...))`.

**Return**: `Result<Void, EnqueueFailure>`.

### consume

```swift
func consume(id: String)
```

Called by the Worker loop in `defer` for each processed event.

**Atomic flow** (single `mutex.withLock`):
1. If `pendingCount > 0`: decrement.
2. If `counts[id]` exists: decrement, remove key if it reaches 0.

**Invariant**: floor at zero. Safe after `flush()`/`suspend()` which reset `counts` but not `pendingCount`.

### isCurrentGeneration

```swift
func isCurrentGeneration(_ generation: UInt64) -> Bool
```

Compares the event's generation with the current one in `MutableState`. Used by the Worker loop to distinguish current events from stale ones.

### currentGeneration

```swift
var currentGeneration: UInt64
```

Atomic read of the current generation. Used by subscriptions to tag entries at registration time.

### flush

```swift
func flush()
```

Atomic flow:
1. Guard `!isTerminated`.
2. `generation &+= 1` (overflow wrapping).
3. `counts = [:]` (reset rate limiters).

**Does not reset** `pendingCount`: stale events release their slot when the worker drains them via `consume(id:)`.

### suspend

```swift
@discardableResult
func suspend() -> Bool
```

Atomic flow:
1. Guard `!isTerminated && !isSuspended`.
2. `isSuspended = true`.
3. `generation &+= 1`.
4. `counts = [:]`.

Combines flush + flag in a single atomic operation. Returns `true` if the transition occurred.

### resume

```swift
@discardableResult
func resume() -> Bool
```

Atomic flow:
1. Guard `isSuspended`.
2. `isSuspended = false`.

Returns `true` if the transition occurred.

### finish

```swift
func finish()
```

Atomic flow:
1. Guard `!isTerminated` → set `isTerminated = true`.
2. If transition occurred: `continuation.finish()`.

Idempotent. Called by `Store.deinit`.

---

## 6. Pipeline Construction

### buildDispatchProcess()

```swift
@MainActor
private func buildDispatchProcess() -> ProcessHandler<S, A>
```

Builds the entire pipeline as composed closures once at init. The pattern is **fold-based**: `Array.reduce` wraps each component around the next step.

### Build-Time Captures

All dependencies are captured as local `let` constants:

```swift
let middlewares = self.middlewares       // already reversed
let resolvers = self.resolvers          // already reversed
let reducers = self.reducers            // forward order
let dispatcher = self.dispatcher
let state = self.state
let readOnly = self.state.readOnly
let onLog = self.onLog
let registry = Subscriptions()          // created here, owned by the closure
```

No `[unowned self]` — zero retain cycles because the closures capture local values, not `self`.

### Dispatch Wrapper

```swift
let dispatch: ReduxDispatch<A> = { limit, actions in
  for action in actions {
    let result = dispatcher.tryEnqueue(
      id: action.id,
      limit: limit,
      (action: action, onSnapshot: nil)
    )
    if case let .failure(error) = result, error != .staleGeneration {
      Task { @MainActor in onLog?(.store("Store discarded action due to \(error.reason).")) }
    }
  }
}
```

Wraps the dispatcher for injection into contexts. Nonisolated, thread-safe.

### Construction Order

```
1. subscriptionChain — closure that evaluates entries post-reducer
2. reduceChain       — iterates reducers forward + subscriptionChain + deferSnapshot
3. resolveChain      — folds resolvers reversed, seed = default error handler
4. runTask           — launches .task fire-and-forget
5. runDeferredTask   — launches .deferred with async handler
6. middlewareChain   — folds middlewares reversed around reduceChain
```

The return value of `buildDispatchProcess()` is `middlewareChain`.

### Closure Dependency Graph

```
middlewareChain
├── captures: reduceChain (as fold seed)
├── captures: resolveChain (for .resolve / throw)
├── captures: runTask (for .task)
├── captures: runDeferredTask (for .deferred)
└── captures: dispatch, onLog, registry, dispatcher, readOnly

reduceChain
├── captures: reducers, state, readOnly, onLog
├── captures: subscriptionChain
└── receives: deferSnapshot as parameter

resolveChain
├── captures: resolvers, readOnly, dispatch, onLog
├── captures: reduceChain (for .reduce / .reduceAs)
└── receives: deferSnapshot as parameter

subscriptionChain
├── captures: registry, dispatcher, readOnly, onLog
└── receives no parameters (reads from registry.entries)

runTask
├── captures: readOnly, onLog, resolveChain
└── receives: body, action, middlewareId

runDeferredTask
├── captures: readOnly, onLog, resolveChain, reduceChain
└── receives: handler, next, action, middlewareId, deferSnapshot
```

---

## 7. Middleware Chain

### Fold Mechanics

```swift
let middlewareChain: MiddlewareChain<S, A> = { _, action, deferSnapshot in
  let seed: @MainActor (A) -> Void = { action in reduceChain(action, deferSnapshot) }
  let chain = middlewares.reduce(seed) { next, middleware in
    { action in
      // ... middleware handling
    }
  }
  chain(action)
}
```

The fold builds a chain where each middleware wraps the next step (`next`). The seed (innermost element) is `reduceChain`.

Since `middlewares` is **reversed** at init, the fold produces:
- `middlewares[0]` (last element of the reversed array = first element of the user-supplied array) as the outermost wrapper.
- The first invocation in the chain is the first middleware provided by the user.

### Exit Handling by Case

#### .next

```swift
case .next:
  onLog?(.middleware(middleware.id, action, .now - start, exit))
  next(action)
```

Forwards to the next middleware with the same action. Logged.

#### .defaultNext

```swift
case .defaultNext:
  next(action)
```

Pass-through. **Not logged**. Indicates that the middleware does not handle this action.

#### .nextAs(A)

```swift
case .nextAs(let newAction):
  onLog?(.middleware(middleware.id, action, .now - start, exit))
  next(newAction)
```

Forwards with a modified action. The next middleware receives the new action.

#### .resolve(SendableError)

```swift
case .resolve(let error):
  onLog?(.middleware(middleware.id, action, .now - start, exit))
  resolveChain(error, action, middleware.id, deferSnapshot)
```

Explicit routing to the resolver chain. `middleware.id` becomes the `origin`.

#### .exit(.success)

```swift
case .exit(.success):
  onLog?(.middleware(middleware.id, action, .now - start, exit))
  reduceChain(action, deferSnapshot)
```

Short-circuit: the middleware chain is interrupted, the action goes directly to the reducers.

#### .exit(.done)

```swift
case .exit(.done):
  onLog?(.middleware(middleware.id, action, .now - start, exit))
  deferSnapshot?(.success(readOnly))
  return
```

Pipeline terminated. No reducer executed. The action is fully handled by the middleware.

#### .exit(.failure(SendableError))

```swift
case .exit(.failure(let error)):
  onLog?(.middleware(middleware.id, action, .now - start, exit))
  deferSnapshot?(.failure(error))
  return
```

Pipeline terminated with error. No reducer, no resolver.

#### .task(TaskHandler<S>)

```swift
case .task(let body):
  runTask(body, action, middleware.id)
  next(action)
```

Launches an asynchronous fire-and-forget task. Pipeline continues immediately with implicit `.next`. **Not logged synchronously** — the log happens at task completion.

#### .deferred(DeferredTaskHandler<S, A>)

```swift
case .deferred(let handler):
  runDeferredTask(handler, next, action, middleware.id, deferSnapshot)
```

Pipeline suspended. The async task will execute the handler and upon completion will call `next(action)` or another terminal point. **Not logged synchronously** — the log happens at completion.

#### throw

```swift
catch {
  onLog?(.middleware(middleware.id, action, .now - start, .resolve(error)))
  resolveChain(error, action, middleware.id, deferSnapshot)
  return
}
```

The throw is caught, logged as `.resolve(error)`, and routed to the resolver chain.

---

## 8. Reducer Chain

### Forward Iteration

```swift
let reduceChain: ReduceChain<S, A> = { action, deferSnapshot in
  for reducer in reducers {
    let start: ContinuousClock.Instant = .now
    let context = ReducerContext<S, A>(state, action)
    let exit = reducer.reduce(context)

    // Logging
    switch exit {
    case .defaultNext: break
    default: onLog?(.reducer(reducer.id, action, .now - start, exit))
    }

    // Flow control
    switch exit {
    case .next, .defaultNext: break
    case .done:
      subscriptionChain()
      deferSnapshot?(.success(readOnly))
      return
    }
  }
  subscriptionChain()
  deferSnapshot?(.success(readOnly))
}
```

### Exit Handling

#### .next

State mutated. Logged. Continues to the next reducer.

#### .defaultNext

Action not handled, no mutation. **Not logged**. Continues to the next reducer.

#### .done

State mutated. Logged. Remaining reducers are skipped. The subscription chain is evaluated immediately, then `deferSnapshot` is called with success.

### Normal Termination

After all reducers (if none returned `.done`):
1. `subscriptionChain()` — evaluates post-reducer entries.
2. `deferSnapshot?(.success(readOnly))` — resumes continuation if present.

### Invariant

The `ReducerContext` is created fresh for each reducer with the same `state` (mutable, reference) and the same `action`. Since the state is a reference type, mutations from one reducer are visible to subsequent ones.

---

## 9. Resolver Chain

### Fold Mechanics

```swift
let resolveChain: ResolveChain<S, A> = { error, action, origin, deferSnapshot in
  let defaultResolver: @MainActor (SendableError, A) -> Void = { error, action in
    onLog?(.resolver("default", action, .zero, .exit(.failure(error)), error))
    deferSnapshot?(.failure(error))
  }
  let chain = resolvers.reduce(defaultResolver) { next, resolver in
    { error, action in
      // ... resolver handling
    }
  }
  chain(error, action)
}
```

The seed (`defaultResolver`) is the chain's terminal: it logs the error as unhandled with id `"default"` and calls `deferSnapshot?(.failure(error))`.

Since `resolvers` is **reversed** at init, the fold produces the same semantics as middlewares: the first resolver in the user-supplied array executes first.

### Exit Handling by Case

#### .next

```swift
case .next:
  onLog?(.resolver(resolver.id, action, .now - start, exitStatus, error))
  next(error, action)
```

Error handled (logged), forwards to the next resolver with error and action unchanged.

#### .defaultNext

```swift
case .defaultNext:
  next(error, action)
```

Error not handled by this resolver. **Not logged**. Forwards to the next.

#### .nextAs(SendableError, A)

```swift
case .nextAs(let newError, let newAction):
  onLog?(.resolver(resolver.id, action, .now - start, exitStatus, error))
  next(newError, newAction)
```

Error and/or action modified. Forwards to the next resolver.

#### .reduce

```swift
case .reduce:
  onLog?(.resolver(resolver.id, action, .now - start, exitStatus, error))
  reduceChain(action, deferSnapshot)
```

Recovery: the error is recovered. Short-circuits to the reduce chain with the current action.

#### .reduceAs(A)

```swift
case .reduceAs(let newAction):
  onLog?(.resolver(resolver.id, action, .now - start, exitStatus, error))
  reduceChain(newAction, deferSnapshot)
```

Recovery with modified action: short-circuits to the reduce chain with the new action.

#### .exit(ExitResult)

```swift
case .exit:
  onLog?(.resolver(resolver.id, action, .now - start, exitStatus, error))
  deferSnapshot?(.success(readOnly))
```

Pipeline terminated. `.success`/`.done` = error handled. `.failure` = error unrecoverable. In both cases `deferSnapshot` receives `.success(readOnly)` (the current state, not the error).

### Seed Terminal

If no resolver handles the error (all `.next`/`.defaultNext`/`.nextAs` traverse the chain to the seed):

```swift
onLog?(.resolver("default", action, .zero, .exit(.failure(error)), error))
deferSnapshot?(.failure(error))
```

The framework logs the error with id `"default"`, duration `.zero`, exit `.exit(.failure(error))`. The `deferSnapshot` receives `.failure(error)`.

No developer-side "default resolver" is required.

---

## 10. Async Paths

### 10.1. runTask — Fire-and-Forget

```swift
let runTask: RunTask<S, A> = { body, action, middlewareId in
  Task {
    let taskStart: ContinuousClock.Instant = .now
    do {
      try await body(readOnly)
      await MainActor.run {
        onLog?(.middleware(middlewareId, action, .now - taskStart, .exit(.success)))
      }
    } catch {
      await MainActor.run {
        onLog?(.middleware(middlewareId, action, .now - taskStart, .resolve(error)))
        resolveChain(error, action, middlewareId, nil)
      }
    }
  }
}
```

**Semantics**:
- The body is `@Sendable (S.ReadOnly) async throws -> Void`.
- The task is launched off `@MainActor` (no `@MainActor` on the Task).
- On success: log with `.exit(.success)` via `MainActor.run`.
- On error: log with `.resolve(error)` and invoke `resolveChain` with `deferSnapshot: nil`. A fire-and-forget task's resolver cannot produce a snapshot.
- The pipeline **does not suspend**: the middleware chain continues immediately with `next(action)`.

### 10.2. runDeferredTask — Pipeline Suspended

```swift
let runDeferredTask: RunDeferredTask<S, A> = { handler, next, action, middlewareId, deferSnapshot in
  Task {
    let taskStart: ContinuousClock.Instant = .now
    do {
      let resumeExit = try await handler(readOnly)
      await MainActor.run {
        onLog?(.middleware(middlewareId, action, .now - taskStart, MiddlewareExit(from: resumeExit)))
        switch resumeExit {
        case .next:             next(action)
        case .nextAs(let a):    next(a)
        case .resolve(let e):   resolveChain(e, action, middlewareId, deferSnapshot)
        case .exit(.success):   reduceChain(action, deferSnapshot)
        case .exit(.done):      deferSnapshot?(.success(readOnly))
        case .exit(.failure(let e)): deferSnapshot?(.failure(e))
        }
      }
    } catch {
      await MainActor.run {
        onLog?(.middleware(middlewareId, action, .now - taskStart, .resolve(error)))
        resolveChain(error, action, middlewareId, deferSnapshot)
      }
    }
  }
}
```

**Semantics**:
- The handler is `@Sendable (S.ReadOnly) async throws -> MiddlewareResumeExit<A>`.
- The task is launched off `@MainActor`.
- The pipeline is **suspended** until the handler completes.
- The `deferSnapshot` is propagated to the resume exit, ensuring that the caller of `dispatch(_:snapshot:)` receives the post-pipeline state.
- On throw: equivalent to `return .resolve(error)`.
- The log uses `MiddlewareExit(from: resumeExit)` to convert `MiddlewareResumeExit` to `MiddlewareExit`.

### 10.3. MiddlewareExit(from:) — Conversion

```swift
init(from resumeExit: MiddlewareResumeExit<A>) {
  self = switch resumeExit {
  case .next: .next
  case let .nextAs(action): .nextAs(action)
  case let .resolve(error): .resolve(error)
  case let .exit(result): .exit(result)
  }
}
```

Maps common cases 1:1. Used only for logging: the `MiddlewareResumeExit` is logged as `MiddlewareExit` for uniformity.

### 10.4. MainActor.run Callback

Both `runTask` and `runDeferredTask` use `await MainActor.run { ... }` to return to MainActor after async work. This ensures that:
- `onLog?` (which is `@MainActor`) is called correctly.
- `resolveChain` and `reduceChain` (both `@MainActor`) are invoked with the correct isolation.
- State mutations in reducers happen on MainActor.

---

## 11. Subscriptions

### 11.1. Subscriptions Class

```swift
extension Store.Worker {
  @MainActor
  final class Subscriptions {
    var entries: [Entry] = []
    func register(_ entry: Entry)            // dedupe-replace
    @discardableResult func unregister(id: String) -> Bool
  }
}
```

Reference semantics: the same instance is shared between the `register`, `unregister`, and `subscriptionChain` closures without needing `inout`.

### 11.2. Entry Struct

```swift
struct Entry {
  let id: String                          // caller-provided identifier
  let origin: A                           // action at the time of registration
  let registeredBy: String                // middleware.id
  let generation: UInt64                  // generation at the time of registration
  let when: SubscriptionPredicate<S>      // @MainActor @Sendable (S.ReadOnly) -> Bool
  let then: SubscriptionHandler<S, A>     // @MainActor @Sendable (S.ReadOnly) -> A
}
```

### 11.3. Register / Unregister

**register**: removes entry with the same `id` (dedupe-replace), appends the new one.

```swift
func register(_ entry: Entry) {
  entries.removeAll { $0.id == entry.id }
  entries.append(entry)
}
```

**unregister**: removes the first entry with matching `id`. Returns `true` if removed.

### 11.4. subscriptionChain Evaluation

```swift
let subscriptionChain: SubscriptionChain = {
  guard !registry.entries.isEmpty else { return }

  var matched: [Subscriptions.Entry] = []
  registry.entries.removeAll { entry in
    // Stale generation → remove silently
    guard dispatcher.isCurrentGeneration(entry.generation) else { return true }

    // Predicate match → remove and add to matched
    if entry.when(readOnly) {
      matched.append(entry)
      return true
    }

    return false
  }

  for entry in matched {
    let start: ContinuousClock.Instant = .now
    let action = entry.then(readOnly)

    let result = dispatcher.tryEnqueue(
      id: action.id,
      limit: 0,
      generation: entry.generation,
      (action: action, onSnapshot: nil)
    )

    switch result {
    case .success:
      onLog?(.subscription(.executed(...)))
    case let .failure(error) where error != .staleGeneration:
      onLog?(.store("Store discarded action due to \(error.reason)."))
    case .failure:
      break
    }
  }
}
```

**Flow**:
1. Scans `entries` with `removeAll(where:)`: removes stale (generation) and matched (predicate) entries.
2. For each matched entry: invokes `then(readOnly)` to produce the action, then `tryEnqueue` with the **original** generation of the subscription (not the current one). This prevents ghost dispatches if a flush occurred between the match and the enqueue.
3. Logging: `.executed` on success, `.store(discard)` on non-stale failure, silent on `.staleGeneration`.

**Invocation**: called at the end of `reduceChain`, both in the normal flow and after `.done`.

---

## 12. Snapshot API

### 12.1. ReadOnlySnapshot Struct

```swift
internal struct ReadOnlySnapshot<S: ReduxState>: Sendable {
  let continuation: CheckedContinuation<Result<Data, Error>, Never>
  let snapshot: @MainActor @Sendable (S.ReadOnly) throws -> Data
}
```

**Properties**:
- `continuation`: `CheckedContinuation` that is resumed at the pipeline's terminal point. Non-throwing (the error is inside the `Result`).
- `snapshot`: `@MainActor` closure that accepts `S.ReadOnly` and produces `Data`. Built by `dispatch(_:snapshot:)` with `JSONEncoder`.

### 12.2. Flow in the Worker Loop

When the Worker loop processes an event with `onSnapshot != nil`:

```swift
let deferSnapshot: SnapshotHandler<S>? = { result in
  switch result {
  case .success(let readOnly):
    do {
      let data = try onSnapshot.snapshot(readOnly)
      onSnapshot.continuation.resume(returning: .success(data))
    } catch {
      onSnapshot.continuation.resume(returning: .failure(error))
    }
  case .failure(let error):
    onSnapshot.continuation.resume(returning: .failure(error))
  }
}
```

### 12.3. Terminal Points

The `deferSnapshot` is called at every terminal point of the pipeline:

| Terminal Point | Argument |
|---|---|
| `reduceChain` completion | `.success(readOnly)` |
| `.exit(.done)` | `.success(readOnly)` |
| `.exit(.failure(e))` | `.failure(e)` |
| Resolver `.exit(...)` | `.success(readOnly)` |
| Resolver seed (unhandled) | `.failure(error)` |
| Deferred `.exit(.done)` | `.success(readOnly)` |
| Deferred `.exit(.failure(e))` | `.failure(e)` |
| Stale generation (worker loop) | `.failure(.staleGeneration)` |
| Task cancellation (worker loop) | `.failure(CancellationError())` |
| Enqueue failure (Worker.dispatch) | `.failure(EnqueueFailure)` |

### 12.4. Continuation Pattern

```swift
public func dispatch<T>(
  _ action: A,
  snapshot: T.Type
) async -> ReduxEncodedSnapshot where T: ReduxStateSnapshot<S> {
  let snapshotClosure: @MainActor @Sendable (S.ReadOnly) throws -> Data = { readOnly in
    let encoder = JSONEncoder()
    let value = T(state: readOnly)
    return try encoder.encode(value)
  }

  return await withCheckedContinuation { continuation in
    let handler = ReadOnlySnapshot<S>(
      continuation: continuation,
      snapshot: snapshotClosure
    )
    worker.dispatch(action, onSnapshot: handler)
  }
}
```

`withCheckedContinuation`: the caller is suspended until a terminal point calls `continuation.resume(returning:)`.

---

## 13. Capacity & Admission Control

### 13.1. dispatcherCapacity

Configured via `StoreOptions`:

```swift
public struct StoreOptions: Sendable {
  public let dispatcherCapacity: Int

  public init(dispatcherCapacity: Int = 256) {
    assert(dispatcherCapacity > 0, "dispatcherCapacity must be greater than 0")
    self.dispatcherCapacity = max(1, dispatcherCapacity)
  }
}
```

- **Default**: 256.
- **Minimum**: 1 (clamped with `max(1, ...)` + `assert` in debug).
- **Semantics**: `pendingCount` counts **queued + in-flight** actions. A slot is released only by `consume(id:)` in the `defer` of the worker loop.

### 13.2. pendingCount

Slot lifecycle:

```
tryEnqueue → pendingCount++ → yield to stream
    ↓
Worker for-await → process pipeline
    ↓
defer { consume(id:) } → pendingCount--
```

A slot is occupied from the moment of enqueue until the synchronous completion of the pipeline (or skip for stale generation). Asynchronous operations (`.task`, `.deferred`) do not occupy additional slots: only their re-entrant dispatches pass through `tryEnqueue`.

### 13.3. Per-Action Counts

When `limit > 0` in `tryEnqueue`:
- `counts[id]` is incremented at enqueue.
- `counts[id]` is decremented by `consume(id:)`.
- If `counts[id] >= limit`: rejection with `.maxDispatchableReached`.
- `flush()` resets `counts` to `[:]`, but subsequent consumes are safe (floor at zero / guard on `counts[id]`).

### 13.4. Complete Slot Lifecycle

```
Enqueue:
  tryEnqueue(id, limit, event)
    mutex.withLock:
      check terminated/suspended/generation/capacity/per-action
      pendingCount += 1
      counts[id] += 1 (if limit > 0)
    continuation.yield(TaggedActionEvent)

Process:
  for await event in events:
    defer { dispatcher.consume(id: event.action.id) }
    // ... pipeline or stale skip

Consume:
  consume(id:)
    mutex.withLock:
      pendingCount -= 1 (floor 0)
      counts[id] -= 1 (remove if 0)
```

---

## 14. Generation Tracking

### 14.1. Flush Semantics

`flush()` invalidates all queued actions without interrupting the action in progress.

**Invariant**: `generation` is a monotonically increasing counter (`&+= 1`, overflow wrapping). Each `TaggedActionEvent` is tagged with the generation at the time of enqueue.

### 14.2. Stale Event Flow

```
1. flush() → generation 0 → 1, counts reset
2. Actions with generation 0 still in the stream buffer
3. Worker loop reads event with generation 0
4. dispatcher.isCurrentGeneration(0) → false
5. event.onSnapshot?.continuation.resume(returning: .failure(.staleGeneration))
6. defer { dispatcher.consume(id:) } → pendingCount--
```

The stale event does not execute the pipeline. If it has a snapshot handler, the continuation is resumed with an error. The slot is still released.

### 14.3. Generation Tagging

Tagging happens in `tryEnqueue`:

```swift
let gen = state.generation  // captured inside withLock
// ...
continuation.yield(TaggedActionEvent(
  action: event.action,
  onSnapshot: event.onSnapshot,
  generation: gen
))
```

The generation is captured atomically together with the `pendingCount` increment, within the same lock.

### 14.4. Subscription Generation

Subscriptions are tagged with the current generation at registration time:

```swift
registry.register(Subscriptions.Entry(
  // ...
  generation: dispatcher.currentGeneration,
  // ...
))
```

In `subscriptionChain`, entries with stale generation are silently removed. Actions produced by matched entries are enqueued with the subscription's original generation:

```swift
dispatcher.tryEnqueue(
  id: action.id,
  limit: 0,
  generation: entry.generation,  // subscription's generation, not current
  (action: action, onSnapshot: nil)
)
```

If a flush occurred between match and enqueue, `tryEnqueue` rejects with `.staleGeneration`.

---

## 15. Suspend/Resume

### 15.1. Suspend

```swift
// Store
nonisolated public func suspend() {
  guard worker.dispatcher.suspend() else { return }
  let onLog = worker.onLog
  Task { @MainActor in onLog?(.store("suspend")) }
}

// Dispatcher
@discardableResult
func suspend() -> Bool {
  mutex.withLock { state in
    guard !state.isTerminated, !state.isSuspended else { return false }
    state.isSuspended = true
    state.generation &+= 1
    state.counts = [:]
    return true
  }
}
```

**Semantics**:
- Atomic operation: flush + suspension in a single `withLock`.
- New `tryEnqueue` calls rejected with `.suspended`.
- In-progress actions are not interrupted.
- Stale actions in the stream are drained by the worker as stale events.

### 15.2. Resume

```swift
// Store
nonisolated public func resume() {
  guard worker.dispatcher.resume() else { return }
  let onLog = worker.onLog
  Task { @MainActor in onLog?(.store("resume")) }
}

// Dispatcher
@discardableResult
func resume() -> Bool {
  mutex.withLock { state in
    guard state.isSuspended else { return false }
    state.isSuspended = false
    return true
  }
}
```

**Semantics**:
- Only resets the `isSuspended` flag. Does not modify generation or counts.
- The dispatcher accepts enqueues again.

### 15.3. Testing Pattern

```swift
// Test: dispatch, suspend, verify, resume
store.dispatch(.fetchData)
store.suspend()
// ... assert on state ...
store.resume()
store.dispatch(.nextAction)
```

**Warning**: these APIs are exclusively for testing. Production use causes silent action loss and inconsistent state.

---

## 16. Logging

### 16.1. Store.Log Enum

```swift
public enum Log: Sendable {
  case middleware(String, A, Duration, MiddlewareExit<S, A>)
  case reducer(String, A, Duration, ReducerExit)
  case resolver(String, A, Duration, ResolverExit<A>, SendableError)
  case subscription(Subscription)
  case store(String)
}
```

### 16.2. Parameters by Case

#### .middleware

| Position | Type | Description |
|---|---|---|
| 1 | `String` | `middleware.id` |
| 2 | `A` | Processed action |
| 3 | `Duration` | Execution time |
| 4 | `MiddlewareExit<S, A>` | Exit signal (includes `.defaultNext` to distinguish pass-through) |

#### .reducer

| Position | Type | Description |
|---|---|---|
| 1 | `String` | `reducer.id` |
| 2 | `A` | Reduced action |
| 3 | `Duration` | Execution time |
| 4 | `ReducerExit` | Exit signal |

#### .resolver

| Position | Type | Description |
|---|---|---|
| 1 | `String` | `resolver.id` (or `"default"` for the seed) |
| 2 | `A` | Action that caused the error |
| 3 | `Duration` | Execution time (`.zero` for the seed) |
| 4 | `ResolverExit<A>` | Exit signal |
| 5 | `SendableError` | Caught error |

#### .subscription

```swift
public enum Subscription: Sendable {
  case subscribed(String, String, A, Duration)
  case executed(String, String, A, Duration, A)
  case unsubscribed(String, String, Duration)
}
```

**subscribed**: `(registeredBy, subId, origin, elapsed)`.

**executed**: `(registeredBy, subId, origin, elapsed, dispatchedAction)`. The fifth parameter is the action produced by `then(readOnly)`. The action enters the pipeline as a standard dispatch and produces its own `.middleware`/`.reducer` logs.

**unsubscribed**: `(canceller, subId, elapsed)`. The first parameter is the id of the middleware that called `unsubscribe`, **not** the original `registeredBy`. Correlate with `.subscribed` via `subId`.

#### .store

| Position | Type | Description |
|---|---|---|
| 1 | `String` | Text message |

Known messages:
- `"flush"` — emitted after `flush()`.
- `"suspend"` — emitted after `suspend()`.
- `"resume"` — emitted after `resume()`.
- `"Store discarded action due to <reason>."` — emitted when `tryEnqueue` fails (except `.staleGeneration`).

### 16.3. Timing Measurement

The framework uses `ContinuousClock.Instant.now` for timing:

```swift
let start: ContinuousClock.Instant = .now
// ... component execution ...
let elapsed: Duration = .now - start
onLog?(.middleware(id, action, elapsed, exit))
```

For `.task` and `.deferred`: the timing measures the entire duration of the async task, from launch to completion.

### 16.4. What Is Not Logged

| Situation | Reason |
|---|---|
| `.defaultNext` from middleware | Pass-through, not handled |
| `.defaultNext` from reducer | Action not relevant |
| `.defaultNext` from resolver | Error not handled by this resolver |
| `.task` / `.deferred` synchronous | The log happens at task completion |
| `staleGeneration` discard | Expected outcome post-flush |

---

## 17. Type Aliases

### Public

| Alias | Signature | Usage |
|---|---|---|
| `SendableError` | `any Error` | Type-erased error for Sendable boundary |
| `ReduxOrigin` | `String` | Id of the middleware that originated an error |
| `ReduxDispatch<A>` | `@Sendable (UInt, A...) -> Void` | Nonisolated dispatch injected into contexts |
| `ReduxEncodedSnapshot` | `Result<Data, Error>` | Return type of `dispatch(_:snapshot:)` |
| `LogHandler<S, A>` | `@MainActor @Sendable (Store<S, A>.Log) -> Void` | Logging callback |
| `MiddlewareHandler<S, A>` | `@MainActor (MiddlewareContext<S, A>) throws -> MiddlewareExit<S, A>` | Middleware closure signature |
| `ReduceHandler<S, A>` | `@MainActor (ReducerContext<S, A>) -> ReducerExit` | Reducer closure signature |
| `ResolveHandler<S, A>` | `@MainActor (ResolverContext<S, A>) -> ResolverExit<A>` | Resolver closure signature |
| `UnsubscribeHandler` | `@MainActor @Sendable (String) -> Void` | Removes subscription by id |
| `MiddlewareArgs<S, A>` | `(S.ReadOnly, ReduxDispatch<A>, A, MiddlewareSubscribe<S, A>, UnsubscribeHandler)` | Destructuring of `MiddlewareContext.args` |
| `ResolverArgs<S, A>` | `(S.ReadOnly, ReduxDispatch<A>, SendableError, ReduxOrigin, A)` | Destructuring of `ResolverContext.args` |
| `TaskHandler<S>` | `@Sendable (S.ReadOnly) async throws -> Void` | Body of `.task` |
| `DeferredTaskHandler<S, A>` | `@Sendable (S.ReadOnly) async throws -> MiddlewareResumeExit<A>` | Body of `.deferred` |
| `SubscriptionPredicate<S>` | `@MainActor @Sendable (S.ReadOnly) -> Bool` | Post-reducer predicate |
| `SubscriptionHandler<S, A>` | `@MainActor @Sendable (S.ReadOnly) -> A` | Action builder on match |

### Internal

| Alias | Signature | Usage |
|---|---|---|
| `ProcessHandler<S, A>` | `@MainActor (S.ReadOnly, A, SnapshotHandler<S>?) -> Void` | Top-level pipeline closure |
| `ActionEvent<S, A>` | `(action: A, onSnapshot: ReadOnlySnapshot<S>?)` | Pre-tagging event |
| `SnapshotHandler<S>` | `@MainActor (Result<S.ReadOnly, SendableError>) -> Void` | Terminal callback |
| `MiddlewareChain<S, A>` | `@MainActor (S.ReadOnly, A, SnapshotHandler<S>?) -> Void` | Middleware chain step |
| `MiddlewareNext<A>` | `@MainActor (A) -> Void` | Forward to the next middleware |
| `RunTask<S, A>` | `@MainActor (@escaping TaskHandler<S>, A, ReduxOrigin) -> Void` | Launches `.task` |
| `RunDeferredTask<S, A>` | `@MainActor (@escaping DeferredTaskHandler<S, A>, @escaping MiddlewareNext<A>, A, ReduxOrigin, SnapshotHandler<S>?) -> Void` | Launches `.deferred` |
| `ReduceChain<S, A>` | `@MainActor (A, SnapshotHandler<S>?) -> Void` | Reduce chain step |
| `ResolveChain<S, A>` | `@MainActor (SendableError, A, ReduxOrigin, SnapshotHandler<S>?) -> Void` | Resolve chain step |
| `SubscriptionChain` | `@MainActor () -> Void` | Post-reducer entries evaluation |

---

## 18. Macros

### 18.1. @ReduxState

```swift
@attached(member, names: named(ReadOnly), named(readOnly), named(init))
public macro ReduxState() = #externalMacro(module: "TinyReduxMacros", type: "ReduxStateMacro")
```

**Target**: `class` (diagnostic if applied to anything else).

**Generates**:

1. **ReadOnly class** — nested `@Observable @MainActor` class conforming to `ReduxReadOnlyState`:
   - `private unowned let state: <ClassName>` — reference to the original state.
   - Get-only computed properties for every stored `var` not marked `@ObservationIgnored`.
   - `let` properties, computed properties, and `@ObservationIgnored` properties are excluded.

2. **readOnly property** — `@ObservationIgnored lazy var readOnly = ReadOnly(self)`.

3. **Designated init** — `nonisolated init(...)` with one parameter for every stored `var` not marked `@ObservationIgnored`. Assigns to the backing fields `_name`.

**Property scanning**:
- Considers only `var` (not `let`).
- Ignores properties with `@ObservationIgnored`.
- Ignores computed properties (those with `accessorBlock`).
- Uses the first binding of each declaration.

### 18.2. @ReduxAction

```swift
@attached(member, names: named(id))
public macro ReduxAction() = #externalMacro(module: "TinyReduxMacros", type: "ReduxActionMacro")
```

**Target**: `enum` (diagnostic if applied to anything else).

**Generates**:

```swift
public var id: String {
  switch self {
  case .<caseName>: return "<caseName>"
  // ... for each case
  }
}
```

Associated values are ignored in the match (pattern without binding). The `return` value is the textual name of the case.

### 18.3. Plugin Registration

```swift
@main
struct TinyReduxMacroPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    ReduxActionMacro.self,
    ReduxStateMacro.self,
  ]
}
```

Target `TinyReduxMacros` compiled as a macro plugin with dependencies `SwiftSyntax`, `SwiftSyntaxMacros`, `SwiftCompilerPlugin`.

---

## 19. Concurrency Model

### 19.1. @MainActor Pipeline

The entire pipeline (middleware → reducer → resolver → subscription) runs on `@MainActor`:

- `Worker.process` is `@MainActor`.
- `Middleware.run`, `Reducer.reduce`, `Resolver.run` are `@MainActor`.
- All contexts (`MiddlewareContext`, `ReducerContext`, `ResolverContext`) are `@MainActor`.
- Internal closures (`reduceChain`, `resolveChain`, `middlewareChain`, `subscriptionChain`) are `@MainActor`.

### 19.2. Nonisolated Boundaries

| Point | Isolation | Reason |
|---|---|---|
| `Store.dispatch(...)` | `nonisolated` | Callable from any isolation |
| `Store.flush()` | `nonisolated` | Callable from any isolation |
| `Store.suspend()` / `resume()` | `nonisolated` | Testing-only, any isolation |
| `Worker.dispatch(...)` | `@Sendable nonisolated` | Dispatch entry point |
| `Dispatcher.tryEnqueue(...)` | `nonisolated` | Thread-safe via Mutex |
| `Dispatcher.consume(id:)` | nonisolated | Thread-safe via Mutex |
| `Dispatcher.flush()` | nonisolated | Thread-safe via Mutex |
| `Dispatcher.finish()` | nonisolated | Thread-safe via Mutex |
| `MiddlewareContext.dispatch` | `nonisolated let` | Sendable, thread-safe |
| `ResolverContext.dispatch` | `nonisolated let` | Sendable, thread-safe |

### 19.3. Sendable Requirements

| Type | Sendable | Reason |
|---|---|---|
| `Store` | `Sendable` | Crosses isolation boundaries |
| `Worker` | `Sendable` | Owned by Store, `nonisolated let` |
| `Dispatcher` | `Sendable` | Accessed from nonisolated and @MainActor |
| `ReduxAction` | `Sendable` | Travels in the stream |
| `ReduxState` | `Sendable` | Owned by Store cross-isolation |
| `MiddlewareExit` | `Sendable` | Contains Sendable closures |
| `MiddlewareResumeExit` | `Sendable` | Crosses Task boundary |
| `ReducerExit` | `Sendable` | Pure enum |
| `ResolverExit` | `Sendable` | Enum with Sendable values |
| `ExitResult` | `Sendable` | Enum with Sendable values |
| `EnqueueFailure` | `Sendable` | Crosses isolation boundaries |
| `TaggedActionEvent` | `Sendable` | Travels in the stream |
| `ReadOnlySnapshot` | `Sendable` | Travels in the stream |
| `StoreOptions` | `Sendable` | Passed to init cross-isolation |

### 19.4. Mutex Usage

`Mutex<MutableState>` (from the `Synchronization` module, Swift 6) protects the Dispatcher's state:

```swift
private let mutex: Mutex<MutableState>
```

`MutableState` is `~Copyable`: the Mutex guarantees exclusive access. Atomic operations:

| Operation | Lock scope |
|---|---|
| `tryEnqueue` | Check + increment + capture generation |
| `consume` | Decrement pendingCount + counts |
| `isCurrentGeneration` | Read generation |
| `currentGeneration` | Read generation |
| `flush` | Increment generation + reset counts |
| `suspend` | Set flag + increment generation + reset counts |
| `resume` | Reset flag |
| `finish` | Set terminated flag |
| `pendingCount` (getter) | Read pendingCount |

**Invariant**: the lock is never held during I/O or yield to the stream. The only operation outside the lock after a decision inside the lock is `continuation.yield(...)`, which is thread-safe by design of `AsyncStream.Continuation`.

---

## 20. Error Flow

### 20.1. Throw → resolveChain

When a middleware throws an exception:

```swift
do {
  exit = try middleware.run(context)
} catch {
  onLog?(.middleware(middleware.id, action, .now - start, .resolve(error)))
  resolveChain(error, action, middleware.id, deferSnapshot)
  return
}
```

The error is logged as `.resolve(error)`, then routed to the resolver chain with:
- `error`: the caught exception.
- `action`: the current action in the middleware.
- `origin`: `middleware.id` of the middleware that threw.
- `deferSnapshot`: propagated to ensure snapshot delivery.

### 20.2. .resolve → resolveChain

An explicit `.resolve(error)` return has the same effect:

```swift
case .resolve(let error):
  onLog?(.middleware(middleware.id, action, .now - start, exit))
  resolveChain(error, action, middleware.id, deferSnapshot)
```

### 20.3. Task Error → resolveChain

Errors from `.task` and `.deferred`:

```swift
// runTask
catch {
  await MainActor.run {
    onLog?(.middleware(middlewareId, action, .now - taskStart, .resolve(error)))
    resolveChain(error, action, middlewareId, nil)  // nil: no snapshot for task
  }
}

// runDeferredTask
catch {
  await MainActor.run {
    onLog?(.middleware(middlewareId, action, .now - taskStart, .resolve(error)))
    resolveChain(error, action, middlewareId, deferSnapshot)  // deferSnapshot preserved
  }
}
```

Key difference: `.task` passes `nil` as `deferSnapshot` (fire-and-forget), `.deferred` preserves the original `deferSnapshot`.

### 20.4. Seed Terminal

If no resolver handles the error:

```swift
let defaultResolver: @MainActor (SendableError, A) -> Void = { error, action in
  onLog?(.resolver("default", action, .zero, .exit(.failure(error)), error))
  deferSnapshot?(.failure(error))
}
```

The error is logged with id `"default"` and duration `.zero`. The `deferSnapshot` receives `.failure(error)`.

---

## 21. Memory Management

### 21.1. No Retain Cycles

The pipeline is built by capturing local variables, not `self`:

```swift
@MainActor
private func buildDispatchProcess() -> ProcessHandler<S, A> {
  let state = self.state       // local capture
  let readOnly = self.state.readOnly
  let onLog = self.onLog
  let dispatcher = self.dispatcher
  // ...
  // From here on, closures capture these constants, not self.
}
```

No `[unowned self]` or `[weak self]` needed in pipeline closures.

### 21.2. Worker Task [weak self]

The Worker loop Task uses `[weak self]` to allow deallocation:

```swift
self.task = Task { @MainActor [weak self] in
  guard let self else { return }
  process = buildDispatchProcess()
  for await event in events {
    // ...
  }
}
```

The `weak self` is only used for the initial guard. After `buildDispatchProcess()`, all closures capture local variables.

### 21.3. ReadOnly — unowned let

The `ReadOnly` class generated by the macro uses `unowned let state`:

```swift
final class ReadOnly: ReduxReadOnlyState {
  private unowned let state: ClassName
  // ...
}
```

`unowned` (not `weak`) because `ReadOnly` is created as a `lazy var` of the state — the lifecycle is guaranteed by the owner.

### 21.4. Store → Worker → Dispatcher

```
Store
├── _state: S         (strong, @MainActor)
└── worker: Worker    (strong, nonisolated let)
      ├── state: S    (strong, @MainActor — same object as Store._state)
      └── dispatcher  (strong, nonisolated let)
```

- `Store` owns `Worker` via `let`.
- `Worker` owns `state` via `var` (same reference as `Store._state`).
- `Worker` owns `Dispatcher` via `let`.
- `Store.deinit` calls `dispatcher.finish()`, terminating the stream and allowing deallocation.

### 21.5. Async Task — No Self

The `.task` and `.deferred` closures capture `readOnly` (from the pipeline build-time), not the state directly. The reference chain is:

```
Task closure → readOnly (local let) → state (unowned, in ReadOnly)
```

This prevents retain cycles: the Task does not keep the Store/Worker alive.

### 21.6. Subscriptions Registry

The `Subscriptions` object is created in `buildDispatchProcess()` as a local variable and captured by the closures. It has no back-reference to the Worker.

```
Pipeline closure → registry: Subscriptions (reference semantics)
                   ├── entries[].when: closure (captures readOnly)
                   └── entries[].then: closure (captures readOnly)
```

Subscription entries capture `readOnly` via the predicate/handler closures. Since `readOnly` is an `unowned let` on the state, there are no cycles.
