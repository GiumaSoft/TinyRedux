Progettazione TinyRedux 3.1

Protocols:

- ReduxAction: Equatable, Identifiable, Sendable
  Azione dispatchabile. Attraversa boundary nonisolated → MainActor.
  Rimossi CustomDebugStringConvertible, CustomStringConvertible (erano nella v3.0).

- ReduxState: Observable, Sendable
  State mutabile. Espone proiezione ReadOnly per middleware/resolver.

- ReduxReadOnlyState: MainActor, Observable, Sendable
  Proiezione read-only dello state.

- Middleware: Identifiable, Sendable
  Side-effects. throwing-Sync su MainActor, non-throwing-Async via context.task (actor isolated) e throwing-Async task.content.

- Reducer: Identifiable, Sendable
  Mutazione pura dello state. non-throwing-Sync, MainActor.

- Resolver: Identifiable, Sendable
  Error recovery. non-throwing-Sync, MainActor.


Reference-Type:

- Store: MainActor, Observable
  Orchestratore dello stack Redux. dispatch() nonisolated, resto MainActor.
  @ObservationIgnored nonisolated let worker: Worker  — Worker è @MainActor → Sendable.
  Store.dispatch() → worker.dispatcher.dispatch(action).
  Store.deinit → worker.dispatcher.finish().

- Store.Log
  Diagnostica/timing pipeline. Enum pubblica con casi:
    .middleware(String, Action, Duration, Result<Bool, any Error>)
    .reducer(String, Action, Duration, Bool)
    .resolver(String, Action, Duration, Bool, any Error)
    .store(String)
  onLog è internal (firma pubblica solo come parametro di Store.init).

- Store.Worker
  Esegue la pipeline. interno @MainActor final class.
  Possiede Dispatcher (dettaglio interno) e la chain per-dispatch come stored property.
  Metodi @MainActor per inferenza (non @Sendable) → risolve il conflitto runNext.
  _next closure cattura solo self (Worker @MainActor → implicitamente Sendable).

  nonisolated let dispatcher: Dispatcher  — Sendable. Accesso diretto da Store via worker.dispatcher.

  Lifecycle:
    Init: creato da Store.init. Crea Dispatcher, riceve middleware/reducers/resolvers.
    Loop: Task interno con `for await action in dispatcher.stream`. Chain copiata fresh per ogni action.
    Store access: weak var store (evita retain cycle Store → Worker → Store).

- Store.Dispatcher (interno a Worker)
  Wrapper Sendable su AsyncStream + Continuation. Dettaglio implementativo.


Value-Type (NON @MainActor — isolamento sulle closure/metodi, non sullo struct):

- AnyMiddleware, AnyReducer, AnyResolver
  Type-erasure via closure. @frozen. Sendable.
  Closure stored @MainActor, struct non-isolated.

- MiddlewareContext
  State ReadOnly, action, dispatch, resolve, task, next. @frozen. Sendable.
  next() @MainActor. dispatch/resolve/task/complete nonisolated (cross-boundary intenzionale).
  Typealias pubblici per leggibilità: Dispatch, Resolve, Next, TaskContext, TaskLauncher.

- ReducerContext
  State mutabile, action. @frozen. Sendable.
  Usato solo su MainActor ma struct non-isolated per Sendable conformance.

- ResolverContext
  State ReadOnly, action, error, source (middleware ID), dispatch, next. @frozen. Sendable.
  Usato solo su MainActor ma struct non-isolated per Sendable conformance.
  Typealias pubblici per leggibilità: Dispatch, Next.

- ReduxOrigin: va rimosso. Il middleware ID passa al resolver come source: String su ResolverContext.


Gerarchia componenti:

  Store [@MainActor, @Observable]
  ├── _state: State                           [@MainActor]
  ├── onLog: ((Log) -> Void)?                 [@MainActor]
  └── worker: Worker                          [nonisolated let, Sendable]
        ├── dispatcher: Dispatcher            [nonisolated let, Sendable]
        │     ├── stream: AsyncStream         [consumato dal for-await]
        │     └── continuation: Continuation  [Sendable, thread-safe]
        ├── middlewares: [AnyMiddleware]      [let, immutabile]
        ├── reducers: [AnyReducer]            [let, immutabile]
        ├── resolvers: [AnyResolver]          [let, immutabile]
        ├── (rate limiting gestito dal Dispatcher, vedi Feature 1)
        ├── middlewareChain: [AnyMiddleware]  [var, per-dispatch, @MainActor]
        ├── resolverChain: [AnyResolver]      [var, per-dispatch, @MainActor]
        ├── task: Task<Void, Never>?          [var, for-await loop, @MainActor]
        └── store: Store? [weak]              [var, @MainActor]


Flussi logici:

  1. Dispatch (nonisolated → MainActor):
     caller → Store.dispatch() → worker.dispatcher.dispatch(action)
                                    │ [yield alla continuation, nonisolated]
                                    ▼
                              AsyncStream buffer
                                    │
                                    ▼
                              Worker for-await loop [MainActor]
                                    │
                                    ▼
                              Worker.process(action)

  2. Pipeline (interamente MainActor):
     process(action)
       │
       ├── middlewareChain = Array(middlewares)
       │
       ▼
     runNextMiddleware(action) ◄──────────────────────┐
       ├── chain vuota → runReducers(action)          │
       │                    │                         │
       │                    ▼                         │
       │                  for reducer in reducers     │
       │                    reducer.reduce(context)   │
       │                                              │
       └── middleware.run(context)                    │
             ├── context.next(action) ────────────────┘
             ├── throws/context.resolve(error) ──┐
             │     runNextResolver(error, action) ◄────────────┐
             │       ├── chain vuota → return (errore non gestito)
             │       └── resolver.run(context)                  │
             │             ├── context.next() ──────────────────┘
             │             └── context.dispatch() → worker.dispatcher [re-enqueue]
             ├── context.dispatch() → worker.dispatcher [re-enqueue, async]
             └── context.task { async work }

  3. Shutdown (nonisolated):
     Store.deinit → worker.dispatcher.finish()
                      │ [termina continuation]
                      ▼
                    stream termina → for-await esce → Task completa



Regole NON NEGOZIABILI:

  1. nonisolated(unsafe) NON accettabile.
     Ogni attraversamento nonisolated → MainActor usa `nonisolated let` (safe, compiler-verified) su tipi Sendable.

  2. NON aprire prompt/domande all'utente durante la pianificazione.
     Il piano resta in discussione libera fino a comando esplicito di attuazione.


Feature (definite):

  1. Rate limiting: check pre-enqueue nel Dispatcher.
     Dispatcher gestisce internamente un Mutex<[String: UInt]> per il contatore.
     tryEnqueue(id, limit) → check + increment atomico, prima di yield alla continuation. [nonisolated]
     decrease(id) → decremento dopo pipeline completa, chiamato dal Worker. [MainActor]
     Mutex necessario: tryEnqueue (nonisolated) e decrease (MainActor) possono accadere in parallelo.
     ActionCounter eliminato come tipo separato.

  2. Log/timing: complete() emette il log, non clock.measure.
     Il timestamp di inizio è catturato prima di run(). complete() calcola elapsed e chiama onLog.
     Supporta timing async: complete() dal task include il tempo totale.
     complete() resta nonisolated + OnceGuard (idempotente, callable da qualsiasi contesto).

  3. Dispatch con completion: nonisolated, callback sullo state risultante.
     Dispatcher trasporta (action, completion?). limit consumato da tryEnqueue al momento dell'enqueue (Feature 1).
     completion: @escaping @Sendable (State.ReadOnly) -> Void — invocata su MainActor dal Worker.
     completion nil → fire-and-forget (dispatch standard).
     Elimina pendingDispatchResult e token UUID — la completion viaggia con l'action nello stream.
     dispatchWithResult() può essere reimplementato sopra come wrapper async.

  4. Store.init — parametri invariati (initialState, middlewares, resolvers, reducers, onLog?).
     Internamente crea Worker. Worker possiede Dispatcher e chain.

  5. Store.state / subscript(dynamicMember:) — API invariata.
     @MainActor, ReadOnly. @dynamicMemberLookup su Store per accesso diretto (store.prop → store.state.prop).

  6. Store.dispatch(maxDispatchable:_:) — nonisolated.
     Rate limiting via Feature 1 (Dispatcher). Internamente: worker.dispatcher.tryEnqueue(id, limit, action).

  7. Store.dispatchWithResult(maxDispatchable:_:) — @MainActor async.
     Reimplementato come wrapper async su Feature 3 (dispatch con completion + withCheckedContinuation).
     Elimina pendingDispatchResult dict e UUID token.

  8. Store.bind(_:maxDispatchable:_:) — @MainActor, Binding<T>.
     Migrazione diretta. Usa dispatch internamente, nessun cambio di firma.

  9. Store.previewState(_:) — factory statica @MainActor.
     Migrazione diretta. Crea Store con pipeline vuota (middleware/reducer/resolver = []).

  10. @CaseID macro — invariato.
      Genera computed `id: String` da enum case name. Nessuna dipendenza dalla pipeline.

  11. StatedMiddleware — @frozen struct, Middleware conformance.
      Weak coordinator pattern invariato. Handler @MainActor throws. Migrazione diretta.

  12. SendableError typealias — invariato. `public typealias SendableError = any Error`.

  13. ReduxOrigin — rimosso.
      Sostituito da `source: String` su ResolverContext (solo middleware ID).
      ResolverContext.origin: ReduxOrigin → ResolverContext.source: String.
      ResolverContext.args aggiornato di conseguenza (ReduxOrigin → String).

  15. Test — i 28 test esistenti devono essere aggiornati per riflettere le modifiche API
      (ReduxOrigin → source: String, rimozione CustomDebugStringConvertible/CustomStringConvertible, ecc.).


Feature (da definire):

  14. Bind bidirezionale (nuovo) — solo in `#if targetEnvironment(simulator)`.
      Analogo a previewState: API di debug/preview per scrivere sullo state da SwiftUI.
      Da progettare: firma, scoping (get/set su keyPath dello State mutabile), safety guard.
