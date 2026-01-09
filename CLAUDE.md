# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test

```bash
swift build          # build the library
swift test           # run all tests (44 tests)
swift test --filter TinyReduxTests/resolverReceivesOrigin  # run a single test
```

Swift 6.0 toolchain required. Strict Concurrency is enforced (`swiftLanguageModes: [.version("6")]`).

## Architecture

TinyRedux is a **Supervised Redux Model** — a unidirectional data flow framework where middleware, resolver, and reducer cooperate in the same dispatch pipeline.

### Dispatch Pipeline

```
dispatch(action)  [nonisolated — callable from any isolation]
    ↓
Worker.Dispatcher → AsyncStream (FIFO, bufferingOldest(256))
    ↓
Worker Task (MainActor) reads stream
    ↓
Middleware chain (reversed order, fold-based, sync — async work via MiddlewareExit)
    ├─ can dispatch, transform, block, or forward actions
    ├─ throws → error routed to resolver chain
    └─ returns MiddlewareExit enum to control pipeline flow
        ↓
Reducer chain (forward order, MainActor — pure state mutations)
    ↓
If middleware threw or returned .resolve:
Resolver chain (reversed order, fold-based, non-throwing — error recovery)
    ├─ can dispatch recovery actions
    └─ returns ResolverExit enum to control error flow
        ↓
completion?(readOnly) — threaded through terminal points (reduce, .exit, resolveChain terminals)
```

Key: middlewares and resolvers are **reversed** at init so the first element in the user-supplied array runs first in the fold chain. Reducers run in forward order.

### Core Types

| Protocol | Role | Context struct |
|---|---|---|
| `Middleware` | Async side effects, throws | `MiddlewareContext` |
| `Reducer` | Pure state mutation (O(1), MainActor) | `ReducerContext` |
| `Resolver` | Error recovery, non-throwing | `ResolverContext` |

Each has a type-erased `Any*` wrapper (`AnyMiddleware`, `AnyReducer`, `AnyResolver`). All three conform to their respective protocols and offer both a closure-based and a wrapping initializer.

**Store** (`@MainActor @Observable @dynamicMemberLookup`) — central hub holding state + pipeline. Read-only state access via `subscript(dynamicMember:)`. Optional `onLog` callback for timing/diagnostics.

**Worker** (`Store.Worker`, `@MainActor`) — owns the pipeline. Built at init, no `start()`. Contains `Dispatcher` (nested type), `buildDispatchProcess()`, and two nonisolated dispatch entry points: `dispatch(maxDispatchable:actions:)` → `Void` (batch) and `dispatch(maxDispatchable:_:completion:)` → `Bool` (single action).

**Dispatcher** (`Store.Worker.Dispatcher`, `Sendable`) — wraps `AsyncStream` with `Mutex`-based rate limiting, generation tracking, and suspend/resume. `tryEnqueue` returns `Bool` (used by `dispatch(_:completion:)` and `dispatchWithResult` for throttle/suspend detection).

**ReduxState** — mutable observable state with a `ReadOnly` associated type projection (`ReduxReadOnlyState`). Resolvers and middlewares see `ReadOnly`; reducers get the mutable state.

### Dispatch API

| Method | Isolation | Completion |
|---|---|---|
| `dispatch(maxDispatchable:_:)` | `nonisolated` | fire-and-forget (variadic `A...`) |
| `dispatch(maxDispatchable:_:completion:)` | `nonisolated` | callback with `State.ReadOnly`, returns `Bool` |
| `dispatchWithResult(maxDispatchable:_:)` | `@MainActor async` | returns `State.ReadOnly` via continuation |

All three go through `Worker.dispatch` → `Dispatcher.tryEnqueue`. The completion travels as part of the `TaggedActionEvent` through the AsyncStream, then is threaded into `process?(readOnly, action, completion)` so that each terminal point in the pipeline calls it with post-mutation state. This ensures `.deferred` middleware paths deliver correct state to completions/continuations.

### Pipeline Construction — `buildDispatchProcess()`

Built once at init, returns `@MainActor (State.ReadOnly, Action, ActionHandler<S>?) -> Void`. Uses **fold pattern** (`Array.reduce`) instead of recursive local functions:

1. **reduce(action, completion)** — seed closure, iterates all reducers in forward order, calls `completion?(readOnly)` after
2. **resolveChain(error, action, origin, completion)** — folds `resolvers` into a single chain; completion forwarded to all terminal points (seed, `.reduce`/`.reduceAs` → reduce, `.exit`)
3. **middlewareChain(readOnly, action, completion)** — folds `middlewares` around `reduce`; seed captures completion. Terminal points (`.exit`, `.resolve`/throw, `.deferred`) forward completion

Captures: all dependencies captured as local `let` at build-time (`state`, `readOnly`, `onLog`, `dispatcher`, arrays). No `[unowned self]` — zero retain cycles.

### Context Pattern

All contexts are `@frozen struct` + `Sendable`. They expose `.args` for destructured access.

`MiddlewareContext` — read-only state, action, dispatch. Pipeline flow controlled by `MiddlewareExit` return value.

`ResolverContext` — read-only state, action, error, origin, dispatch. Pipeline flow controlled by `ResolverExit` return value.

`ReducerContext` — mutable state, action. Pipeline flow controlled by `ReducerExit` return value.

## Abstraction

### Protocols

- **ReduxAction**: `Equatable`, `Identifiable`, `Sendable`
  Azione dispatchabile. Attraversa boundary nonisolated → MainActor.
  Macro `@CaseID` (`@attached(member)`) sintetizza `id` dal nome del case enum.

- **ReduxState**: `@MainActor`, `AnyObject`, `Observable`, `Sendable`
  State mutabile. Espone proiezione `ReadOnly` per middleware/resolver.

- **ReduxReadOnlyState**: `@MainActor`, `AnyObject`, `Observable`, `Sendable`
  Proiezione read-only dello state.

- **Middleware**: `Identifiable`, `Sendable`
  Side-effects. `run()` throwing-Sync su MainActor, ritorna `MiddlewareExit`. Async via `.task` (fire-and-forget) o `.deferred` (async throws, return-based).

- **Reducer**: `Identifiable`, `Sendable`
  Mutazione pura dello state. non-throwing-Sync, MainActor.

- **Resolver**: `Identifiable`, `Sendable`
  Error recovery. non-throwing-Sync, MainActor.

### Reference Types

- **Store**: `@MainActor`, `@Observable`
  Orchestratore dello stack Redux. `dispatch()` nonisolated, resto MainActor.
  `@ObservationIgnored nonisolated let worker: Worker` — Worker è `@MainActor` → Sendable.
  `Store.dispatch()` → `worker.dispatch(action)`.
  `Store.deinit` → `worker.dispatcher.finish()`.
  API aggiuntive: `flush()` (nonisolated, scarta pending actions via Dispatcher generation),
  `suspend()` / `resume()` (nonisolated, testing-only — flush + flag che blocca nuovi enqueue),
  `bind(_:maxDispatchable:_:)` (SwiftUI Binding che dispatcha su write),
  `bind(_:)` (simulator-only, direct state mutation per previews),
  `previewState(_:)` (simulator-only, direct state mutation per previews).

- **Store.Log**
  Diagnostica/timing pipeline. Enum pubblica con casi:
    `.middleware(String, Action, Duration, MiddlewareExit<S, A>)`
    `.reducer(String, Action, Duration, ReducerExit)`
    `.resolver(String, Action, Duration, ResolverExit<A>, SendableError)`
    `.store(String)`
  Ogni componente logga il proprio exit enum. `MiddlewareExit` usato come tipo log (include `.defaultNext`);
  deferred handler ritorna `MiddlewareResumeExit`, convertito a `MiddlewareExit` via `init(from:)` per logging.
  `onLog` è internal (firma pubblica solo come parametro di `Store.init`).

- **Store.Worker**: `@MainActor final class`
  Esegue la pipeline. Possiede `Dispatcher` (tipo nestato) e `buildDispatchProcess()` (fold-based).
  `nonisolated let dispatcher: Dispatcher` — Sendable. Accesso diretto da Store via `worker.dispatcher`.
  Due entry point nonisolated: `dispatch(maxDispatchable:actions:)` → `Void` (batch), `dispatch(maxDispatchable:_:completion:)` → `Bool` (singola).
  `onLog` passato a init (catturato a build-time come optional, invocato con optional chaining `onLog?(...)` per zero-overhead).
  `private var state: S` — possiede lo state direttamente, no weak back-reference.

  Lifecycle:
    Init: creato da `Store.init`. Crea Dispatcher, chiama `buildDispatchProcess()`, avvia Task.
    Loop: Task interno con `for await event in dispatcher.events`. Chain costruita via fold per ogni dispatch.
    Shutdown: `dispatcher.finish()` → stream termina → for-await esce → Task completa.

- **Store.Worker.Dispatcher**: `final class Sendable`
  Wrapper su `AsyncStream` + `Continuation` con `Mutex<MutableState>`-based rate limiting e generation tracking.
  `MutableState` (`~Copyable`): `generation: UInt64`, `counts: [String: UInt]`, `isFinished: Bool`, `isSuspended: Bool`.
  `tryEnqueue(id:limit:_:) -> Bool` — check + increment atomico, tagga con generation corrente, yield alla continuation.
  `decrease(id:)` — decremento dopo pipeline completa, chiamato dal worker loop.
  `isCurrentGeneration(_:)` — confronto generazione per skip elementi stale.
  `flush()` — incrementa generation, reset counters. Elementi stale → completion-only nel worker loop.
  `suspend()` — flush + `isSuspended = true` atomico. Nuovi enqueue rifiutati. Testing-only.
  `resume()` — `isSuspended = false`. Testing-only.
  `finish()` — termina lo stream, idempotente. Chiamato da `Store.deinit`.
  `Mutex` necessario: `tryEnqueue` (nonisolated) e `decrease` (MainActor) possono accadere in parallelo.

### Value Types

`@frozen` struct. `Sendable`. `@MainActor` inherited dai protocol dove applicabile.

- **AnyMiddleware, AnyReducer, AnyResolver**
  Type-erasure via closure. `@frozen`. `@MainActor` inherited dal protocol conformance.
  Tutti e tre hanno init closure-based e wrapping da conformer (`init<M: Middleware>(_:)`, ecc.).

- **MiddlewareContext**
  State (ReadOnly), dispatch, action. Pipeline flow controllato dal return value `MiddlewareExit`.

- **ReducerContext**
  State mutabile, action. Pipeline flow controllato dal return value `ReducerExit`.

- **ResolverContext**
  State ReadOnly, action, error, origin (`String`), dispatch. Pipeline flow controllato dal return value `ResolverExit`.

### Component Hierarchy

```
Store [@MainActor, @Observable, @dynamicMemberLookup]
├── _state: State                             [@ObservationIgnored, internal]
└── worker: Worker                            [nonisolated let, Sendable]
      ├── dispatcher: Dispatcher              [nonisolated let, Sendable]
      │     ├── stream: AsyncStream           [consumato dal for-await]
      │     ├── continuation: Continuation    [Sendable, thread-safe]
      │     └── mutex: Mutex<MutableState>    [generation + counts + isFinished]
      ├── middlewares: [AnyMiddleware]        [let, reversed, immutabile]
      ├── reducers: [AnyReducer]              [let, forward order, immutabile]
      ├── resolvers: [AnyResolver]            [let, reversed, immutabile]
      ├── onLog: ((Log) -> Void)?             [let, catturato a build-time]
      ├── process: closure?                   [var, built once at init]
      ├── task: Task<Void, Never>?            [var, for-await loop]
      └── state: S                             [var, owned directly]
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
                            Worker for-await loop [MainActor]
                                  │
                                  ▼
                            dispatchProcess?(readOnly, action, completion)

2. Pipeline (interamente MainActor, fold-based):
   dispatchProcess?(readOnly, action, completion)
     │
     ├── middlewareChain = middlewares.reduce(reduce) { fold }
     │
     ▼
   middlewareChain(action)
     │
     ├── middleware.run(context) → MiddlewareExit
     │     ├── .next / .nextAs(a2) → next step in fold → ... → reduce
     │     ├── .resolve(error)     → resolveChain(error, action, id, completion)
     │     ├── .exit(.success)     → reduceChain(action, completion), short-circuit al reducer
     │     ├── .exit(.failure(e))  → completion?(readOnly), pipeline terminata con errore
     │     ├── .task(body)         → runTask(body) + next (implicito, no completion)
     │     ├── .deferred(handler)  → Task { handler(readOnly) } — pipeline sospesa, completion threaded
     │     └── throws              → resolveChain(error, action, id, completion)
     │
     ├── reduce(action, completion) [innermost step]
     │     └── for reducer in reducers → reducer.reduce(context)
     │     └── completion?(readOnly)
     │
     └── resolveChain(error, action, origin, completion)
           └── chain = resolvers.reduce(seed) { fold }
                 └── resolver.run(context) → ResolverExit
                       ├── .next / .nextAs(e2, a2) → next step in fold
                       ├── .reduce / .reduceAs(a2) → short-circuit to reduce(action, completion)
                       ├── .exit(.success)          → completion?(readOnly), errore gestito
                       └── .exit(.failure)          → completion?(readOnly), errore non gestibile
     │
     ▼
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

2. `MainActor.assumeIsolated` NON accettabile.
   MAI usare `assumeIsolated`. Se il compiler non può provare l'isolamento, risolvere con il type system (typealias, attributi, refactoring), non con asserzioni runtime.

### Features

1. **Rate limiting**: check pre-enqueue nel Dispatcher.
   `tryEnqueue(id, limit)` → check + increment atomico via `Mutex`, prima di yield alla continuation.
   `decrease(id)` → decremento dopo pipeline completa.

2. **Log/timing**: automatico per tutti i componenti (middleware, reducer, resolver).
   Timestamp catturato prima di `run()`/`reduce()`. Elapsed calcolato dopo return dell'enum e passato a `onLog`.
   Per `.task`/`.deferred`: solo log async (durata task/completamento), nessun sync log.

3. **Generation tracking / Flush**: `Dispatcher.flush()` incrementa un contatore `generation` e resetta i rate-limit counters.
   Ogni `TaggedActionEvent` è taggato con la generation corrente al momento dell'enqueue.
   Nel worker loop, `isCurrentGeneration` verifica: elementi stale → completion-only (no pipeline).
   `Store.flush()` espone come API pubblica nonisolated.

4. **Suspend / Resume** (testing-only): `Dispatcher.suspend()` esegue flush + setta `isSuspended = true` in singola `withLock`.
   `tryEnqueue` guarda `!state.isSuspended` dopo `!state.isFinished` — nuove action rifiutate (ritorna `false`).
   `Dispatcher.resume()` resetta il flag. `Store.suspend()` / `Store.resume()` espongono come API pubblica nonisolated.

5. **Dispatch con completion**: nonisolated, callback sullo state risultante.
   Dispatcher trasporta `(action, completion?)`. La completion viaggia con l'action nello stream.
   Il for-await loop passa la completion a `process?(readOnly, action, completion)` — non la chiama direttamente.
   Ogni terminal point della pipeline chiama `completion?(readOnly)` con lo state post-mutazione.
   Per `.deferred`: la completion è catturata nel Task, invocata solo dopo che il handler ritorna e la pipeline completa.
   Per `.task`: fire-and-forget, il suo `resolveChain` secondario passa `nil` come completion.
   `dispatchWithResult()` reimplementato come wrapper async sopra (`withCheckedContinuation`).

## Discussing Feature

Redesign delle astrazioni del framework. Decisioni finali.

### 1. @MainActor Pipeline

Pipeline interamente MainActor non-bloccante. Protocol `Middleware`, `Reducer`, `Resolver` vincolati a `@MainActor`.
Escape da MainActor: **Dispatcher** (Sendable, Mutex) e **middleware task** (@Sendable, async off-MainActor).

### 2. Type-Erasure: Struct Concrete

`@frozen` struct concreti, non existentials. `@MainActor` inherited dai protocol.

### 3. Worker State Ownership

Worker possiede state direttamente (`private var state: S`). No weak back-reference, no retain cycle.

### 4. Enum Return Pattern

`run()` ritorna un enum invece di closure-based exits. Elimina `OnceGuard`, compiler enforza single exit.

```swift
@frozen
public enum MiddlewareResumeExit<A: ReduxAction>: Sendable {
  case next                                                     // forward action corrente
  case nextAs(A)                                                // forward action modificata
  case resolve(SendableError)                                       // route a resolver chain
  case exit(ExitResult)                                             // uscita forzata dalla pipeline
}
// No .defaultNext — nel resume context l'azione è già gestita.

@frozen
public enum MiddlewareExit<S: ReduxState, A: ReduxAction>: Sendable {
  case next                                                     // forward action corrente (gestita)
  case defaultNext                                              // pass-through — azione non gestita
  case nextAs(A)                                                // forward action modificata
  case resolve(SendableError)                                       // route a resolver chain
  case exit(ExitResult)                                             // uscita forzata dalla pipeline
  case task(@Sendable (S.ReadOnly) async throws -> Void)        // fire-and-forget, .next implicito
  case deferred(@Sendable (S.ReadOnly) async throws -> MiddlewareResumeExit<A>)  // handler con state, return-based
  init(from resumeExit: MiddlewareResumeExit<A>)                // converte per log deferred/task
}
// Middleware.run() throws → MiddlewareExit<S, A>
// throws → catch → resolver chain
// Usato anche come tipo in Store.Log.middleware (include .defaultNext per distinguere pass-through).

@frozen
public enum ResolverExit<A: ReduxAction>: Sendable {
  case next                 // forward error + action correnti (gestito)
  case defaultNext          // pass-through — errore non gestito da questo resolver
  case nextAs(SendableError, A)   // forward error/action modificati
  case reduce               // short-circuit a reducer (action corrente)
  case reduceAs(A)          // short-circuit a reducer (action modificata)
  case exit(ExitResult)                   // .success → gestito, .failure → non gestibile
}
// Resolver.run() → ResolverExit<A> (non-throwing)
```

**Reducer**: `reduce` → `@MainActor (ReducerContext<S, A>) -> ReducerExit`. Usa `.next`/`.defaultNext` — stessa convenzione di logging degli altri exit enum.

### 5. Resolve → Reduce

`.reduce`/`.reduceAs(A)` short-circuita la resolve chain verso il reducer.
Primo resolver che gestisce l'errore vince. Elimina `defaultResolver`.

### 6. Deferred (async throws, return-based)

`.deferred` è `async throws` con accesso allo state read-only. Il handler ritorna un `MiddlewareResumeExit` per continuare la pipeline:

```swift
return .deferred { state in
  let user = try await api.fetchUser()
  return .nextAs(.setUser(user))  // .next per action corrente
}
```

Pattern identico a `.task` (single Task, auto-catch). `throw` equivale a `return .resolve(error)`. `MiddlewareResumeExit` non ha `.deferred` né `.task`.

### 7. Pipeline Flows

**MiddlewareExit**:
```
middlewareChain(readOnly, action, completion)
│
├── Middleware A
│   ├── .next              → Middleware B (same action) — azione gestita
│   ├── .defaultNext       → Middleware B (same action) — pass-through, non gestita
│   ├── .nextAs(a2)        → Middleware B (modified action)
│   ├── .resolve(error)    → resolveChain(error, action, "A", completion)
│   ├── .exit(.success)    → reduceChain(action, completion), short-circuit al reducer
│   ├── .exit(.failure(e)) → completion?(readOnly), pipeline terminata con errore
│   ├── .task(body)        → runTask(body, no completion) + Middleware B (.next implicito)
│   ├── .deferred(handler) → Task { handler(readOnly) } — pipeline sospesa, completion threaded
│   │                        return .next             → Middleware B → seed → completion
│   │                        return .nextAs(a2)       → Middleware B (modified) → seed → completion
│   │                        return .resolve(e)       → resolveChain(..., completion)
│   │                        return .exit(.success)   → reduceChain(action, completion)
│   │                        return .exit(.failure)   → completion?(readOnly)
│   │                        throws                   → resolveChain(error, ..., completion)
│   └── throws             → resolveChain(error, action, "A", completion)
│
└── seed: reduce(action, completion)   ← terminale
```

**ResolverExit**:
```
resolveChain(error, action, origin, completion)
│
├── Resolver A
│   ├── .next              → Resolver B (same error/action) — errore gestito
│   ├── .defaultNext       → Resolver B (same error/action) — pass-through, non gestito
│   ├── .nextAs(e2, a2)    → Resolver B (modified error/action)
│   ├── .reduce            → reduce(action, completion)  ← short-circuit
│   ├── .reduceAs(a2)      → reduce(a2, completion)      ← short-circuit
│   ├── .exit(.success)    → completion?(readOnly), stop — errore gestito
│   └── .exit(.failure)    → completion?(readOnly), stop — errore non gestibile
│
└── seed: onLog(.resolver("default", .exit(.failure(error)))), completion?(readOnly)  ← terminale
```

### 8. Contesti Semplificati

| Context | Mantiene | Rimuove |
|---|---|---|
| MiddlewareContext | state (ReadOnly), action, dispatch (nonisolated) | next(), resolve(), complete(), task, OnceGuard |
| ReducerContext | state, action | complete(), OnceGuard |
| ResolverContext | state, action, error, origin, dispatch (nonisolated) | next(), complete(), OnceGuard |

### 9. Log/Timing Automatico

Framework gestisce timing internamente per tutti i componenti (timestamp prima di `run()`/`reduce()`, elapsed dopo return dell'enum, `onLog`).
`OnceGuard` eliminato — il pattern enum return enforza un singolo exit a compile-time.

## Conventions

- All public types must be `Sendable`. Context structs are `@frozen`.
- `ContinuousClock` for timing (not `DispatchTime`). `Duration` for elapsed time.
- Property sort order: `@Wrapped`, then by access level (open → public → internal → private), `let` before `var`, instance before static.
- SwiftUI views: separate `struct` for properties, `extension: View` for body, nested private `Content` struct.
- Tests use Swift Testing framework (`@Test`, `#expect`), not XCTest.
- Indentation: 2 spaces, no tabs. Preserve the existing code structure and formatting style — match surrounding code when editing (brace placement, blank lines between sections, closure layout, parameter alignment).
