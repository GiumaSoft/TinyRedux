# TinyRedux Architecture

TinyRedux is a **Supervised Redux Model** — a unidirectional data flow framework where middleware, reducer, and resolver cooperate in the same dispatch pipeline.

## Table of Contents

- [Dispatch Pipeline](#dispatch-pipeline)
- [Core Types](#core-types)
  - [ReduxAction](#reduxaction)
  - [ReduxState](#reduxstate)
  - [Store](#store)
- [Pipeline Components](#pipeline-components)
  - [Middleware](#middleware)
  - [Reducer](#reducer)
  - [Resolver](#resolver)
- [Logging](#logging)
- [Dispatcher](#dispatcher)
- [Utilities](#utilities)
- [Examples](#examples)

---

## Dispatch Pipeline

```
                          nonisolated
                     ┌──────────────────┐
    any thread ────▶ │ store.dispatch() │
                     └────────┬─────────┘
                              │
                              ▼
                     ┌──────────────────┐
                     │   ActionCounter  │  throttle per action.id
                     └────────┬─────────┘
                              │
                              ▼
                     ┌──────────────────┐
                     │   Dispatcher     │  upstream → relay Task → downstream
                     │   (Mutex-based)  │
                     └────────┬─────────┘
                              │ AsyncStream
                              ▼
                ┌────────────────────────────┐
                │  Store.worker (@MainActor) │
                └─────────────┬──────────────┘
                              │
              ┌───────────────▼─────────────────┐
              │       Middleware Chain          │
              │   (reversed order, sync)        │
              │                                 │
              │   context.next() ───────────┐   │
              │   context.task { } (async)  │   │
              │   context.dispatch()        │   │
              │   throws → resolver chain  │   │
              └───────────────┬─────────────┘───┘
                              │
              ┌───────────────▼────────────────┐
              │        Reducer Chain           │
              │   (forward order, @MainActor)  │
              │                                │
              │   Pure state mutations         │
              │   state.counter += 1           │
              └───────────────┬────────────────┘
                              │
                        if middleware threw:
                              │
              ┌───────────────▼────────────────┐
              │       Resolver Chain           │
              │   (reversed order, non-throw)  │
              │                                │
              │   Error recovery               │
              │   context.dispatch() recovery  │
              │   context.next() forward error │
              └────────────────────────────────┘
```

**Key:** middlewares and resolvers are **reversed** at init so the first element in the user-supplied array runs first in the chain. Reducers run in forward order.

---

## Core Types

### ReduxAction

Protocol for dispatchable actions. Requires `Identifiable`, `Equatable`, and `Sendable`. The `id` property groups actions by case name for throttling via `maxDispatchable`.

The `@CaseID` macro auto-generates `id` from the enum case name:

```swift
@CaseID
enum AppActions: ReduxAction {
  case increase
  case decrease
  case setHeader(String)
  case runEffectDemo
}
// .increase.id == "increase"
// .setHeader("hello").id == "setHeader"  (associated value ignored)
```

### ReduxState

Mutable observable state held by the Store. Conformers expose a `ReadOnly` projection — middlewares and resolvers only see `ReadOnly`, reducers get the mutable state.

```swift
@Observable
@MainActor
final class AppState: ReduxState {
  var counter: Int = 0
  var header: String = ""
  var dates: [Date] = []

  lazy var readOnly = ReadOnlyAppState(self)
}
```

### Store

Central hub: `@MainActor @Observable @dynamicMemberLookup`.

```swift
let store = Store(
  initialState: AppState(),
  middlewares: [loggingMiddleware, effectMiddleware],
  resolvers: [errorResolver],
  reducers: [counterReducer, dateReducer],
  onLog: { log in print(reduxLogFormatter(log)) }
)
```

**Dispatch** is `nonisolated` — callable from any isolation domain:

```swift
store.dispatch(.increase)
store.dispatch(maxDispatchable: 1, .runEffectDemo)  // throttle: max 1 buffered
```

**Read state** via dynamic member lookup:

```swift
Text("Counter: \(store.counter)")   // reads state.readOnly.counter
```

**SwiftUI Binding** dispatches on write:

```swift
TextField("Header", text: store.bind(\.header) { .setHeader($0) })
```

---

## Pipeline Components

### Middleware

Intercepts actions **before** reducers. Can dispatch new actions, launch async tasks, transform or block actions.

**Context API:**

| Property / Method | Description |
|---|---|
| `action` | The dispatched action |
| `dispatch(limit, actions...)` | Enqueue new actions |
| `resolve(error)` | Send error to resolver chain |
| `task { state in ... }` | Launch async work with read-only state |
| `next()` | Forward action to next middleware/reducer |
| `next(action)` | Forward a different action |
| `complete(result)` | Mark as handled, emit timing log |
| `args` | Destructured: `(dispatch, resolve, task, next, action)` |

`next()` and `complete()` are **idempotent** — second call is a silent no-op.

**Sync middleware — forward all actions with logging:**

```swift
let loggingMiddleware = AnyMiddleware<AppState, AppActions>(id: "logger") { context in
  print("Action: \(context.action)")
  context.complete()
  try context.next()
}
```

**Async middleware — side effects via `context.task`:**

```swift
let effectMiddleware = AnyMiddleware<AppState, AppActions>(id: "effects") { context in
  let (dispatch, resolve, task, next, action) = context.args

  switch action {
  case .runEffectDemo:
    dispatch(0, .setEffectRunning(true))

    task { state in
      try await Task.sleep(nanoseconds: 1_000_000_000)
      let timestamp = Date().formatted(date: .abbreviated, time: .standard)
      dispatch(0, .setEffectMessage("Done at \(timestamp)"), .setEffectRunning(false))
      context.complete()
    }

    return  // don't call next — action handled
  default:
    break
  }

  try next(action)
}
```

**Stateful middleware — coordinator persists across dispatches:**

```swift
final class TimerCoordinator: @unchecked Sendable {
  var cancellables: Set<AnyCancellable> = []
}

let timerMiddleware = StatedMiddleware<AppState, AppActions>(
  id: "timer",
  coordinator: TimerCoordinator()
) { coordinator, context in
  let (dispatch, _, _, next, action) = context.args

  switch action {
  case .startAutoCounter:
    Timer.publish(every: 1.0, on: .main, in: .common)
      .autoconnect()
      .sink { @Sendable _ in dispatch(0, .increase) }
      .store(in: &coordinator.cancellables)
    context.complete()
  case .stopAutoCounter:
    coordinator.cancellables.removeAll()
    context.complete()
  default:
    break
  }

  try next(action)
}
```

**Middleware that throws — error auto-routed to resolver chain:**

```swift
let validationMiddleware = AnyMiddleware<AppState, AppActions>(id: "validator") { context in
  if case .runEffectDemoFailure = context.action {
    throw MyError.invalid  // auto-fires complete(.failure(error)), then resolver chain
  }
  try context.next()
}
```

---

### Reducer

Pure state mutation, runs on `@MainActor`. No side effects, no async, no dispatch.

**Context API:**

| Property / Method | Description |
|---|---|
| `state` | Mutable state reference |
| `action` | The action being reduced |
| `complete(succeeded)` | Mark as handled, emit timing log |
| `args` | Destructured: `(state, action)` |

```swift
let counterReducer = AnyReducer<AppState, AppActions>(id: "counter") { context in
  let (state, action) = context.args

  switch action {
  case .increase:
    state.counter += 1
    context.complete()
  case .decrease:
    state.counter -= 1
    context.complete()
  default:
    break
  }
}

let dateReducer = AnyReducer<AppState, AppActions>(id: "dates") { context in
  let (state, action) = context.args

  switch action {
  case .insertDate:
    state.dates.append(Date.now)
    context.complete()
  case .removeDate:
    if !state.dates.isEmpty {
      state.dates.removeLast()
      context.complete()
    }
  default:
    break
  }
}
```

---

### Resolver

Error recovery, runs when a middleware throws. Non-throwing. Can dispatch recovery actions.

**Context API:**

| Property / Method | Description |
|---|---|
| `state` | Read-only state |
| `action` | The action that triggered the error |
| `error` | The captured error |
| `origin` | `.middleware(id)` — identifies the source |
| `dispatch(limit, actions...)` | Enqueue recovery actions |
| `next()` | Forward error to next resolver |
| `next(error, action)` | Forward a different error/action |
| `complete(succeeded)` | Mark as handled, emit timing log |
| `args` | Destructured: `(state, dispatch, next, origin, error, action)` |

```swift
let errorResolver = AnyResolver<AppState, AppActions>(id: "errorHandler") { context in
  let (_, dispatch, next, origin, error, action) = context.args

  switch origin {
  case .middleware(let id) where id == "effects":
    let message = "Caught: \(String(describing: error))"
    dispatch(0,
      .setEffectAlertMessage(message),
      .setEffectAlertPresented(true),
      .setEffectRunning(false)
    )
    context.complete()

  default:
    break
  }

  next(error, action)
}
```

**Error flow:**

```
Middleware throws
    │
    ▼
catch block in Store pipeline
    ├── context.complete(.failure(error))
    └── resolveChain(error, action, .middleware(id))
            │
            ▼
        Resolver 1 ──next()──▶ Resolver 2 ──next()──▶ ... (seed: no-op)
```

---

## Logging

The `onLog` callback receives `Store.Log` events for every pipeline step:

```swift
public enum Log: Sendable {
  case store(String)
  case middleware(String, Action, Duration, Result<Bool, Error>)
  case reducer(String, Action, Duration, Bool)
  case resolver(String, Action, Duration, Bool, Error)
}
```

| Case | Fields |
|---|---|
| `.store` | Diagnostic message (e.g. `"dispatch .increase"`) |
| `.middleware` | `(id, action, elapsed, Result<Bool, Error>)` |
| `.reducer` | `(id, action, elapsed, succeeded)` |
| `.resolver` | `(id, action, elapsed, succeeded, error)` |

Timing uses `ContinuousClock.now` at the start of each step; `Duration` is computed when `complete()` fires.

**Log formatter example:**

```swift
func reduxLogFormatter<S, A>(_ log: Store<S, A>.Log) -> String
  where S: ReduxState, A: ReduxAction
{
  switch log {
  case let .store(message):
    "ℹ️ [STORE] \(message)"

  case let .middleware(id, action, elapsed, .success(true)):
    "ℹ️ [MIDDLEWARE] \(id) processed .\(action.debugDescription) (\(elapsed.fmt()))"

  case let .middleware(id, action, elapsed, .success(false)):
    "🚫 [MIDDLEWARE] \(id) failed .\(action.debugDescription) (\(elapsed.fmt()))"

  case let .middleware(id, action, elapsed, .failure(error)):
    "🚫 [MIDDLEWARE] \(id) threw \"\(error)\" for .\(action.debugDescription) (\(elapsed.fmt()))"

  case let .reducer(id, action, elapsed, succeeded) where succeeded:
    "ℹ️ [REDUCER] \(id) reduced .\(action.debugDescription) (\(elapsed.fmt()))"

  case let .reducer(id, action, elapsed, _):
    "🚫 [REDUCER] \(id) failed .\(action.debugDescription) (\(elapsed.fmt()))"

  case let .resolver(id, action, elapsed, succeeded, error) where succeeded:
    "ℹ️ [RESOLVER] \(id) resolved \"\(error)\" for .\(action.debugDescription) (\(elapsed.fmt()))"

  case let .resolver(id, action, elapsed, _, error):
    "🚫 [RESOLVER] \(id) unresolved \"\(error)\" for .\(action.debugDescription) (\(elapsed.fmt()))"
  }
}
```

**Console output:**

```
ℹ️ [STORE] dispatch .runEffectDemo
ℹ️ [MIDDLEWARE] effects processed .runEffectDemo (3ms)
ℹ️ [REDUCER] counter reduced .setEffectRunning true (0ms)
ℹ️ [REDUCER] counter reduced .setEffectMessage "Done at Feb 24, 2026" (0ms)
```

---

## Dispatcher

Serializes action dispatch through an `AsyncStream` relay with flush support.

```
dispatch()                        Store.worker (@MainActor)
    │                                     ▲
    ▼                                     │
┌───────────┐    relay Task   ┌───────────────┐
│ upstream  │ ──────────────▶ │  downstream   │
│ (write)   │   cooperative   │    (read)     │
└───────────┘   thread pool   └───────────────┘
```

- **`dispatch(_:)`** — yields to upstream via `Mutex`-protected continuation
- **`flush()`** — hot-swaps upstream, increments generation counter, discards buffered actions
- **`finish()`** — terminates upstream, cancels relay Task
- **`actions`** — single-consumption downstream stream

Thread-safety guaranteed by `Mutex` from the `Synchronization` framework. No `NSLock`.

---

## Utilities

| Type | Description |
|---|---|
| `OnceGuard` | `Mutex`-based one-shot guard. `tryConsume()` returns `true` once. Powers idempotent `next()`/`complete()`. |
| `ActionCounter` | `Mutex`-based per-action throttle. `tryEnqueue(id:limit:)` + `decrease(id:)`. |
| `Duration.fmt()` | Formats duration: `"3ms"`, `"5s"`, `"2m"`, `"1h30m"`. |
| `@CaseID` | Macro generating stable `id` from enum case name. |

---

## Examples

### Minimal Setup

```swift
// 1. State
@Observable @MainActor
final class CounterState: ReduxState {
  var count: Int = 0
  lazy var readOnly = ReadOnlyCounterState(self)
}

// 2. Actions
@CaseID
enum CounterAction: ReduxAction {
  case increment
  case decrement
}

// 3. Reducer
let counterReducer = AnyReducer<CounterState, CounterAction>(id: "counter") { context in
  let (state, action) = context.args
  switch action {
  case .increment: state.count += 1
  case .decrement: state.count -= 1
  }
  context.complete()
}

// 4. Store
let store = Store(
  initialState: CounterState(),
  middlewares: [],
  resolvers: [],
  reducers: [counterReducer]
)

// 5. Use
store.dispatch(.increment)
```

### Full Pipeline: Middleware + Reducer + Resolver + Log

```swift
let store = Store(
  initialState: AppState(),
  middlewares: [effectMiddleware, timerMiddleware],
  resolvers: [errorResolver],
  reducers: [counterReducer, dateReducer],
  onLog: { log in print(reduxLogFormatter(log)) }
)

// Sync action → middleware forwards → reducer mutates
store.dispatch(.increase)

// Async action → middleware launches task → dispatches result
store.dispatch(.runEffectDemo)

// Throttled → max 1 buffered action of this type
store.dispatch(maxDispatchable: 1, .runEffectDemo)

// SwiftUI binding → dispatches on write
TextField("Title", text: store.bind(\.header) { .setHeader($0) })
```
