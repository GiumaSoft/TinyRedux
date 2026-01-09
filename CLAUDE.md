# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test

```bash
swift build          # build the library
swift test           # run all tests (23 tests)
swift test --filter TinyReduxTests/resolverReceivesOrigin  # run a single test
```

Swift 6.0 toolchain required. Strict Concurrency is enforced (`swiftLanguageModes: [.version("6")]`).

## Architecture

TinyRedux is a **Supervised Redux Model** — a unidirectional data flow framework where middleware, resolver, and reducer cooperate in the same dispatch pipeline.

### Dispatch Pipeline

```
dispatch(action)  [nonisolated — callable from any isolation]
    ↓
DispatchWorker.Dispatcher → AsyncStream (FIFO, bufferingOldest(256))
    ↓
DispatchWorker Task (MainActor) reads stream
    ↓
Middleware chain (reversed order, fold-based, sync — async work via context.task)
    ├─ can dispatch, transform, block, or forward actions
    ├─ throws → error routed to resolver chain
    └─ calls context.next() to continue
        ↓
Reducer chain (forward order, MainActor — pure state mutations)
    ↓
If middleware threw:
Resolver chain (reversed order, fold-based, non-throwing — error recovery)
    ├─ can dispatch recovery actions
    └─ calls context.next() to forward error
        ↓
element.completion?(readOnly)  — optional per-dispatch callback
```

Key: middlewares and resolvers are **reversed** at init so the first element in the user-supplied array runs first in the fold chain. Reducers run in forward order.

### Core Types

| Protocol | Role | Context struct |
|---|---|---|
| `Middleware` | Async side effects, throws | `MiddlewareContext` |
| `Reducer` | Pure state mutation (O(1), MainActor) | `ReducerContext` |
| `Resolver` | Error recovery, non-throwing | `ResolverContext` |

Each has a type-erased `Any*` wrapper (`AnyMiddleware`, `AnyReducer`, `AnyResolver`). Note: `AnyReducer` does **not** conform to the `Reducer` protocol — it's closure-based.

**Store** (`@MainActor @Observable @dynamicMemberLookup`) — central hub holding state + pipeline. Read-only state access via `subscript(dynamicMember:)`. Optional `onLog` callback for timing/diagnostics.

**DispatchWorker** (`Store.DispatchWorker`, `@MainActor`) — owns the pipeline. Built at init, no `start()`. Contains `Dispatcher` (nested type), `buildDispatchProcess()`, and a nonisolated `dispatch(maxDispatchable:_:completion:)` entry point.

**Dispatcher** (`Store.DispatchWorker.Dispatcher`, `Sendable`) — wraps `AsyncStream` with `Mutex`-based rate limiting. `tryEnqueue` returns `Bool` (used only by `dispatchWithResult` for the throttled path).

**ReduxState** — mutable observable state with a `ReadOnly` associated type projection (`ReduxReadOnlyState`). Resolvers only see `ReadOnly`; reducers get the mutable state. Middlewares access state only through the `task` launcher.

### Dispatch API

| Method | Isolation | Completion |
|---|---|---|
| `dispatch(_:)` | `nonisolated` | fire-and-forget |
| `dispatch(_:completion:)` | `nonisolated` | callback with `State.ReadOnly` after pipeline |
| `dispatchWithResult(_:)` | `@MainActor async` | returns `State.ReadOnly` via continuation |

All three go through `DispatchWorker.dispatch` → `Dispatcher.tryEnqueue`. The completion travels as part of the `DispatchElement` tuple through the AsyncStream — no UUID/token, just FIFO pairing.

### Pipeline Construction — `buildDispatchProcess()`

Built once at init, returns `@MainActor (State.ReadOnly, Action) -> Void`. Uses **fold pattern** (`Array.reduce`) instead of recursive local functions:

1. **reduce** — seed closure, iterates all reducers in forward order
2. **resolveChain** — folds `resolvers` into a single `ResolveNext` chain per invocation
3. **middlewareChain** — folds `middlewares` around `reduce`, each step wrapping the previous `next`

Captures: `[unowned self]` for store access, `onLog` captured at build-time with `if let onLog` for zero-overhead when nil.

### Context Pattern

All contexts are `@frozen struct` + `Sendable`. They expose:
- `.args` for destructured access (e.g., `let (dispatch, resolve, task, next, action) = context.args`)
- `.next()` guarded by `OnceGuard` (idempotent, second call is no-op)
- `.complete()` guarded by `OnceGuard` (emits timing via `onLog` when enabled)

`MiddlewareContext` does **not** have a `state` property — state is accessible only inside the `task` launcher closure.

`ResolverContext.origin` is `Origin` enum (`.middleware(id)`) instead of a plain `String`.

`ResolverContext.next()` is `@MainActor` (resolver pipeline runs entirely on MainActor).

### Utilities

- **OnceGuard** — `NSLock`-based one-shot guard for idempotent `next()`/`complete()` calls

## Abstraction

### Protocols

- **ReduxAction**: `Equatable`, `Identifiable`, `Sendable`
  Azione dispatchabile. Attraversa boundary nonisolated → MainActor.

- **ReduxState**: `Observable`, `Sendable`
  State mutabile. Espone proiezione `ReadOnly` per middleware/resolver.

- **ReduxReadOnlyState**: `@MainActor`, `Observable`, `Sendable`
  Proiezione read-only dello state.

- **Middleware**: `Identifiable`, `Sendable`
  Side-effects. throwing-Sync su MainActor, non-throwing-Async via `context.task` (actor isolated) e throwing-Async `task.content`.

- **Reducer**: `Identifiable`, `Sendable`
  Mutazione pura dello state. non-throwing-Sync, MainActor.

- **Resolver**: `Identifiable`, `Sendable`
  Error recovery. non-throwing-Sync, MainActor.

### Reference Types

- **Store**: `@MainActor`, `@Observable`
  Orchestratore dello stack Redux. `dispatch()` nonisolated, resto MainActor.
  `@ObservationIgnored nonisolated let worker: DispatchWorker` — DispatchWorker è `@MainActor` → Sendable.
  `Store.dispatch()` → `worker.dispatch(action)`.
  `Store.deinit` → `worker.dispatcher.finish()`.

- **Store.Log**
  Diagnostica/timing pipeline. Enum pubblica con casi:
    `.middleware(String, Action, Duration, Result<Bool, any Error>)`
    `.reducer(String, Action, Duration, Bool)`
    `.resolver(String, Action, Duration, Bool, any Error)`
    `.store(String)`
  `onLog` è internal (firma pubblica solo come parametro di `Store.init`).

- **Store.DispatchWorker**: `@MainActor final class`
  Esegue la pipeline. Possiede `Dispatcher` (tipo nestato) e `buildDispatchProcess()` (fold-based).
  `nonisolated let dispatcher: Dispatcher` — Sendable. Accesso diretto da Store via `worker.dispatcher`.
  `nonisolated func dispatch(maxDispatchable:_:completion:)` — entry point unico, `Void`.
  `onLog` passato a init (catturato a build-time con `if let onLog` per zero-overhead).
  `weak var store: Store?` (evita retain cycle). Computed `state: State` via `store!._state`.

  Lifecycle:
    Init: creato da `Store.init`. Crea Dispatcher, chiama `buildDispatchProcess()`, avvia Task.
    Loop: Task interno con `for await element in dispatcher.actions`. Chain costruita via fold per ogni dispatch.
    Shutdown: `dispatcher.finish()` → stream termina → for-await esce → Task completa.

- **Store.DispatchWorker.Dispatcher**: `final class Sendable`
  Wrapper su `AsyncStream` + `Continuation` con `Mutex`-based rate limiting.
  `tryEnqueue(id:limit:_:) -> Bool` — check + increment atomico, prima di yield alla continuation. Nonisolated.
  `decrease(id:)` — decremento dopo pipeline completa, chiamato dal worker loop. MainActor.
  `Mutex` necessario: `tryEnqueue` (nonisolated) e `decrease` (MainActor) possono accadere in parallelo.

### Value Types

NON `@MainActor` — isolamento sulle closure/metodi, non sullo struct.

- **AnyMiddleware, AnyReducer, AnyResolver**
  Type-erasure via closure. `@frozen`. `Sendable`.
  Closure stored `@MainActor`, struct non-isolated.

- **MiddlewareContext**
  Action, dispatch, resolve, task, next. `@frozen`. `Sendable`.
  Nessuna proprietà `state` — lo stato è accessibile solo dentro la closure `task`.
  `next()` `@MainActor`. `dispatch`/`resolve`/`task`/`complete` nonisolated.
  Typealias pubblici: `Dispatch`, `Resolve`, `Next`, `TaskContext`, `TaskLauncher`.

- **ReducerContext**
  State mutabile, action. `@frozen`. `Sendable`.
  Usato solo su MainActor ma struct non-isolated per Sendable conformance.

- **ResolverContext**
  State ReadOnly, action, error, origin (`Origin` enum), dispatch, next. `@frozen`. `Sendable`.
  `Origin` enum: `.middleware(String)`.
  `next()` `@MainActor` (resolver pipeline esegue interamente su MainActor).
  Typealias pubblici: `Dispatch`, `Next`.

### Component Hierarchy

```
Store [@MainActor, @Observable]
├── _state: State                             [@MainActor]
├── onLog: ((Log) -> Void)?                   [@MainActor]
└── worker: DispatchWorker                    [nonisolated let, Sendable]
      ├── dispatcher: Dispatcher              [nonisolated let, Sendable]
      │     ├── stream: AsyncStream           [consumato dal for-await]
      │     ├── continuation: Continuation    [Sendable, thread-safe]
      │     └── counts: Mutex<[String:UInt]>  [rate limiting]
      ├── middlewares: [AnyMiddleware]        [let, reversed, immutabile]
      ├── reducers: [AnyReducer]              [let, forward order, immutabile]
      ├── resolvers: [AnyResolver]            [let, reversed, immutabile]
      ├── onLog: ((Log) -> Void)?             [let, catturato a build-time]
      ├── dispatchProcess: closure?           [var, built once at init]
      ├── task: Task<Void, Never>?            [var, for-await loop]
      └── store: Store? [weak]                [var, accesso a state]
```

### Logical Flows

```
1. Dispatch (nonisolated → MainActor):
   caller → Store.dispatch() → worker.dispatch()
                                  │ [dispatcher.tryEnqueue, nonisolated]
                                  ▼
                            AsyncStream buffer
                                  │
                                  ▼
                            DispatchWorker for-await loop [MainActor]
                                  │
                                  ▼
                            dispatchProcess?(readOnly, action)

2. Pipeline (interamente MainActor, fold-based):
   dispatchProcess?(readOnly, action)
     │
     ├── middlewareChain = middlewares.reduce(reduce) { fold }
     │
     ▼
   middlewareChain(action)
     │
     ├── middleware.run(context)
     │     ├── context.next(action) → next step in fold → ... → reduce
     │     ├── throws → catch → resolveChain(error, action, .middleware(id))
     │     ├── context.resolve(error) → resolveChain
     │     ├── context.dispatch() → worker.dispatch [re-enqueue]
     │     └── context.task { async work }
     │
     ├── reduce(action) [innermost step]
     │     └── for reducer in reducers → reducer.reduce(context)
     │
     └── resolveChain(error, action, origin)
           └── chain = resolvers.reduce(seed) { fold }
                 └── resolver.run(context)
                       ├── context.next() → next step in fold
                       └── context.dispatch() → worker.dispatch [re-enqueue]
     │
     ▼
   element.completion?(readOnly)
   dispatcher.decrease(id:)

3. Shutdown (nonisolated):
   Store.deinit → worker.dispatcher.finish()
                    │ [termina continuation]
                    ▼
                  stream termina → for-await esce → Task completa
```

### Rules

1. `nonisolated(unsafe)` NON accettabile.
   Ogni attraversamento nonisolated → MainActor usa `nonisolated let` (safe, compiler-verified) su tipi Sendable.

### Features

1. **Rate limiting**: check pre-enqueue nel Dispatcher.
   `tryEnqueue(id, limit)` → check + increment atomico via `Mutex`, prima di yield alla continuation.
   `decrease(id)` → decremento dopo pipeline completa.

2. **Log/timing**: `complete()` emette il log, non `clock.measure`.
   Timestamp di inizio catturato prima di `run()`. `complete()` calcola elapsed e chiama `onLog`.
   `if let onLog` a build-time: quando nil, `complete = { _ in }` (zero overhead).

3. **Dispatch con completion**: nonisolated, callback sullo state risultante.
   Dispatcher trasporta `(action, completion?)`. La completion viaggia con l'action nello stream — no UUID/token, FIFO pairing.
   `dispatchWithResult()` reimplementato come wrapper async sopra (`withCheckedContinuation`).

## Conventions

- All public types must be `Sendable`. Context structs are `@frozen`.
- `ContinuousClock` for timing (not `DispatchTime`). `Duration` for elapsed time.
- Property sort order: `@Wrapped`, then by access level (open → public → internal → private), `let` before `var`, instance before static.
- SwiftUI views: separate `struct` for properties, `extension: View` for body, nested private `Content` struct.
- Tests use Swift Testing framework (`@Test`, `#expect`), not XCTest.
- Indentation: 2 spaces, no tabs. Preserve the existing code structure and formatting style — match surrounding code when editing (brace placement, blank lines between sections, closure layout, parameter alignment).
