# TinyRedux — Guida

## Indice

1. [Introduzione](#1-introduzione)
2. [Concetti Redux](#2-concetti-redux)
3. [Primi Passi](#3-primi-passi)
4. [State](#4-state)
5. [Actions](#5-actions)
6. [Reducer](#6-reducer)
7. [Store](#7-store)
8. [Middleware](#8-middleware)
9. [Resolver](#9-resolver)
10. [Pipeline di Dispatch](#10-pipeline-di-dispatch)
11. [Rate Limiting](#11-rate-limiting)
12. [Logging e Diagnostica](#12-logging-e-diagnostica)
13. [Pattern Avanzati](#13-pattern-avanzati)
14. [Riferimento Rapido](#14-riferimento-rapido)

---

## 1. Introduzione

TinyRedux è un framework Swift per la gestione dello stato applicativo basato sul pattern **Supervised Redux** — un modello a flusso di dati unidirezionale in cui middleware, reducer e resolver cooperano all'interno della stessa pipeline di dispatch.

A differenza di un Redux classico, TinyRedux integra nativamente:

- **Concurrency Swift 6** — strict concurrency, `@MainActor`, `Sendable`, zero `unsafe`
- **Observation** — lo state è `@Observable`, SwiftUI reagisce automaticamente ai cambiamenti
- **Error recovery** — i resolver gestiscono gli errori senza interrompere il flusso applicativo
- **Rate limiting** — throttling integrato per action, senza librerie esterne

Il framework è progettato per applicazioni SwiftUI su iOS 18+ e macOS 15+.

---

## 2. Concetti Redux

Prima di utilizzare TinyRedux è utile comprendere i principi alla base del pattern Redux.

### Flusso unidirezionale

In un'architettura Redux, i dati scorrono in una sola direzione:

```
Action → Pipeline → State → UI → (user interaction) → Action → ...
```

L'interfaccia utente non modifica mai lo stato direttamente. Ogni cambiamento nasce da un'**action** che attraversa una **pipeline** prima di arrivare allo stato. Questo rende il comportamento dell'app prevedibile e tracciabile.

### State

Lo **state** è la singola fonte di verità dell'applicazione. Contiene tutti i dati necessari alla UI. In TinyRedux lo state è un oggetto `@Observable` — SwiftUI si aggiorna automaticamente quando le proprietà cambiano.

### Action

Un'**action** è un valore che descrive *cosa è successo*: un tap, un risultato di rete, un timer scaduto. Le action sono il solo modo per richiedere un cambiamento dello stato. Sono `Equatable` e `Sendable` — possono attraversare i confini di concurrency in sicurezza.

### Reducer

Un **reducer** è una funzione pura che riceve lo stato corrente e un'action, e produce il nuovo stato. "Pura" significa: nessun side effect, nessuna chiamata di rete, nessun accesso al disco — solo assegnamenti sullo state. In TinyRedux i reducer restituiscono un segnale (`.next` o `.defaultNext`) per indicare se lo stato è stato effettivamente modificato.

### Middleware

Un **middleware** si inserisce nella pipeline *prima* dei reducer. È il luogo designato per i side effect: chiamate API, timer, logging, validazione. Un middleware può:

- lasciare passare l'action (`.next`)
- modificarla (`.nextAs`)
- bloccarla (`.exit`)
- lanciare lavoro asincrono (`.task`, `.deferred`)
- segnalare un errore (`.resolve`, `throw`)

### Resolver

Un **resolver** gestisce gli errori che emergono dalla pipeline. Quando un middleware lancia un errore o ritorna `.resolve(error)`, la catena di resolver decide come procedere: dispatch di action di recovery, retry, log, o semplicemente drop dell'errore.

### La pipeline completa

```
                         ┌─────────────────────────────────────────────────────┐
                         │                    STORE                            │
                         │                                                     │
  ┌──────────┐           │   ┌────────────┐    ┌──────────┐    ┌──────────┐    │
  │          │  action   │   │            │    │          │    │          │    │
  │    UI    │──────────────▶│ Middleware │───▶│ Reducer  │    │ Resolver │    │
  │          │           │   │  chain.    │    │  chain   │    │  chain   │    │
  └──────────┘           │   └────┬───────┘    └────┬─────┘    └──────────┘    │
       ▲                 │        │                 │                ▲         │
       │                 │        │   error/throw   │                │         │
       │                 │        └─────────────────┼────────────────┘         │
       │                 │                          │                          │
       │                 │                          ▼                          │
       │                 │                    ┌────────────┐                   │
       │                 │                    │   State    │                   │
       │  observation    │                    │ (mutato)   │                   │
       └─────────────────┼────────────────────┤            │                   │
                         │                    └────────────┘                   │
                         └─────────────────────────────────────────────────────┘
```

Il ciclo è sempre lo stesso: **action → middleware → reducer → state → UI**. Se un middleware segnala un errore, il flusso devia verso i resolver, che possono ridirigere ai reducer o terminare la pipeline.

Ogni componente ha un ruolo preciso:

| Componente | Responsabilità | Accesso allo state |
|---|---|---|
| **Middleware** | Mondo esterno (API, timer, I/O, validazione) | Read-only |
| **Reducer** | Mutazione dello state (pura, sincrona) | Read-write |
| **Resolver** | Gestione errori (recovery, logging, fallback) | Read-only |

---

## 3. Primi Passi

Un esempio minimale per capire come i pezzi si combinano.

### Definire lo State

```swift
@Observable @MainActor
final class CounterState: ReduxState {
  var count: Int = 0
  lazy var readOnly = ReadOnlyCounterState(self)
}

@Observable @MainActor
final class ReadOnlyCounterState: ReduxReadOnlyState {
  let state: CounterState
  init(_ state: CounterState) { self.state = state }
  var count: Int { state.count }
}
```

### Definire le Actions

```swift
@CaseID
enum CounterAction: ReduxAction {
  case increment
  case decrement
}
```

### Definire un Reducer

```swift
let counterReducer = AnyReducer<CounterState, CounterAction>(id: "counter") { context in
  let (state, action) = context.args
  switch action {
  case .increment:
    state.count += 1
    return .next
  case .decrement:
    state.count -= 1
    return .next
  }
}
```

### Creare lo Store e dispatchiare

```swift
let store = Store(
  initialState: CounterState(),
  middlewares: [],
  resolvers: [],
  reducers: [counterReducer]
)

store.dispatch(.increment)   // count: 1
store.dispatch(.increment)   // count: 2
store.dispatch(.decrement)   // count: 1
```

### Usare con SwiftUI

```swift
struct CounterView: View {
  let store: Store<CounterState, CounterAction>

  var body: some View {
    VStack {
      Text("Count: \(store.count)")          // dynamic member lookup
      Button("+") { store.dispatch(.increment) }
      Button("-") { store.dispatch(.decrement) }
    }
  }
}
```

---

## 4. State

### ReduxState

Lo state applicativo conforma al protocollo `ReduxState`:

```swift
@MainActor
public protocol ReduxState: AnyObject, Observable, Sendable {
  associatedtype ReadOnly: ReduxReadOnlyState where ReadOnly.State == Self
  var readOnly: ReadOnly { get }
}
```

Lo state è:

- **Reference type** (`AnyObject`) — la mutazione avviene in-place, non per copia
- **Observable** — SwiftUI rileva automaticamente i cambiamenti alle proprietà
- **Sendable** — sicuro da passare tra contesti di concurrency
- **MainActor** — le mutazioni avvengono sempre sul main thread

Ogni state espone una proiezione **read-only** tramite l'associated type `ReadOnly`. Solo i reducer vedono lo state mutabile; middleware e resolver ricevono la vista read-only.

### ReduxReadOnlyState

La proiezione read-only è una classe separata che espone solo le proprietà in lettura:

```swift
@MainActor
public protocol ReduxReadOnlyState: AnyObject, Observable, Sendable {
  associatedtype State: ReduxState
  init(_ state: State)
}
```

Questa separazione è intenzionale: i middleware e i resolver non possono mai modificare lo stato direttamente — possono solo leggere lo stato corrente e dispatchiare nuove action.

---

## 5. Actions

Un'action conforma al protocollo `ReduxAction`:

```swift
public protocol ReduxAction: Identifiable, Equatable, Sendable {
  var id: String { get }
}
```

La proprietà `id` identifica il *tipo* di action (non l'istanza specifica). Viene usata per:

- **Rate limiting** — il throttle raggruppa per `id`
- **Logging** — identificare quale action sta attraversando la pipeline

### @CaseID

Per le action definite come enum, la macro `@CaseID` sintetizza automaticamente `id` dal nome del case, ignorando i valori associati:

```swift
@CaseID
enum AppAction: ReduxAction {
  case increment
  case setName(String)
  case fetchUser(id: Int)
}

// .increment.id          == "increment"
// .setName("Alice").id   == "setName"
// .fetchUser(id: 42).id  == "fetchUser"
```

---

## 6. Reducer

Un reducer è il solo componente autorizzato a modificare lo stato. Conforma al protocollo:

```swift
@MainActor
public protocol Reducer: Identifiable, Sendable {
  associatedtype S: ReduxState
  associatedtype A: ReduxAction
  var id: String { get }
  var reduce: @MainActor (ReducerContext<S, A>) -> ReducerExit { get }
}
```

### ReducerContext

Il context fornisce tutto il necessario per la riduzione:

| Proprietà | Tipo | Descrizione |
|---|---|---|
| `state` | `S` | Lo state mutabile — l'unico punto dove scrivere |
| `action` | `A` | L'action da ridurre |
| `args` | `(S, A)` | Tuple per destructuring rapido |

### ReducerExit

Il valore di ritorno indica al framework se lo stato è cambiato:

| Caso | Significato |
|---|---|
| `.next` | Action gestita — stato modificato. Loggato. |
| `.defaultNext` | Pass-through — action non rilevante, nessun cambiamento. Non loggato. |

Questa distinzione è usata dal sistema di logging per tracciare quali reducer hanno effettivamente reagito.

### AnyReducer

Per creare reducer inline si usa `AnyReducer`, un wrapper type-erased basato su closure:

```swift
let userReducer = AnyReducer<AppState, AppAction>(id: "user") { context in
  let (state, action) = context.args

  switch action {
  case .setName(let name):
    state.userName = name
    return .next

  case .setAge(let age):
    guard age >= 0 else { return .defaultNext }
    state.userAge = age
    return .next

  default:
    return .defaultNext
  }
}
```

### Regole

- **Solo assegnamenti**: niente side effect, niente dispatch, niente async
- **Determinismo**: dati gli stessi input, produce sempre lo stesso output
- **O(1)**: solo operazioni sincrone; lavoro più complesso va nei middleware
- **Multipli reducer**: possono coesistere, ognuno responsabile di una porzione dello state. Vengono eseguiti tutti in ordine (forward order), non si escludono a vicenda

---

## 7. Store

Lo Store è l'orchestratore centrale. Tiene lo stato, assembla la pipeline, e fornisce l'interfaccia di dispatch.

```swift
@MainActor @Observable @dynamicMemberLookup
public final class Store<S: ReduxState, A: ReduxAction> {

  public init(
    initialState state: S,
    middlewares: [AnyMiddleware<S, A>],
    resolvers: [AnyResolver<S, A>],
    reducers: [AnyReducer<S, A>],
    onLog: (@Sendable (Log) -> Void)? = nil
  )
}
```

### Dispatchiare action

Il dispatch è **nonisolated** — può essere chiamato da qualsiasi contesto di concurrency:

```swift
// Fire-and-forget, una o più action
store.dispatch(.increment)
store.dispatch(.increment, .setName("Alice"))

// Con completion — callback dopo che la pipeline ha completato
store.dispatch(.increment) { readOnly in
  print("New count: \(readOnly.count)")
}

// Async con risultato — sospende fino al completamento della pipeline
let state = await store.dispatchWithResult(.increment)
print("New count: \(state.count)")
```

### Leggere lo state

Lo Store espone lo state via `@dynamicMemberLookup` — si accede alle proprietà della proiezione read-only direttamente:

```swift
Text("Count: \(store.count)")       // legge state.readOnly.count
Text("Name: \(store.userName)")     // legge state.readOnly.userName
```

### SwiftUI Binding

`bind` crea un `Binding<T>` che legge dallo state e dispatchia in scrittura:

```swift
TextField("Nome", text: store.bind(\.userName) { .setName($0) })
```

Il mapper ritorna `A?` — se ritorna `nil` il dispatch viene saltato:

```swift
Slider(value: store.bind(\.volume) { newValue in
  newValue > 0 ? .setVolume(newValue) : nil    // ignora volume zero
})
```

### Preview

Per le SwiftUI previews, `previewState` crea uno store con pipeline vuota:

```swift
#Preview {
  CounterView(store: .previewState(CounterState()))
}
```

---

## 8. Middleware

Il middleware è il luogo per i side effect. Si inserisce nella pipeline prima dei reducer e controlla il flusso attraverso il valore di ritorno — un enum `MiddlewareExit`.

### Protocollo

```swift
@MainActor
public protocol Middleware: Identifiable, Sendable {
  associatedtype S: ReduxState
  associatedtype A: ReduxAction
  var id: String { get }
  func run(_ context: MiddlewareContext<S, A>) throws -> MiddlewareExit<S, A>
}
```

### MiddlewareContext

| Proprietà | Tipo | Descrizione |
|---|---|---|
| `state` | `S.ReadOnly` | Vista read-only dello stato corrente |
| `action` | `A` | L'action in transito |
| `dispatch` | `@Sendable (UInt, A...) -> Void` | Dispatchia nuove action (nonisolated) |
| `args` | `(S.ReadOnly, @Sendable (UInt, A...) -> Void, A)` | Tuple per destructuring |

Il primo parametro di `dispatch` è il limite di rate (`0` = illimitato).

### MiddlewareExit

Il valore di ritorno di `run()` determina come prosegue la pipeline:

| Caso | Effetto |
|---|---|
| `.next` | L'action prosegue invariata al prossimo middleware/reducer |
| `.nextAs(action)` | L'action viene sostituita e prosegue |
| `.resolve(error)` | L'errore viene inviato alla catena di resolver |
| `.exit(.success)` | La pipeline termina — action gestita |
| `.exit(.failure(error))` | La pipeline termina con errore |
| `.task { state in ... }` | Lancia lavoro async fire-and-forget; la pipeline prosegue immediatamente con `.next` implicito |
| `.deferred { state in ... }` | La pipeline si sospende; il handler ritorna un `MiddlewareResumeExit` per riprenderla |

Lanciare un errore con `throw` è equivalente a ritornare `.resolve(error)`.

### Middleware sincrono

Il caso più semplice — ispeziona o trasforma l'action e la lascia passare:

```swift
let logger = AnyMiddleware<AppState, AppAction>(id: "logger") { context in
  print("→ \(context.action)")
  return .next
}
```

Bloccare un'action:

```swift
let guard = AnyMiddleware<AppState, AppAction>(id: "guard") { context in
  if case .dangerousAction = context.action {
    return .exit(.success)       // action consumata, non arriva ai reducer
  }
  return .next
}
```

Trasformare un'action:

```swift
let transform = AnyMiddleware<AppState, AppAction>(id: "transform") { context in
  if case .setName(let name) = context.action {
    return .nextAs(.setName(name.trimmingCharacters(in: .whitespaces)))
  }
  return .next
}
```

### Middleware con task asincrono

`.task` lancia lavoro in background senza bloccare la pipeline. L'action originale prosegue immediatamente; il risultato del task viene dispatchiato come nuova action:

```swift
let fetcher = AnyMiddleware<AppState, AppAction>(id: "fetcher") { context in
  let (_, dispatch, action) = context.args

  guard case .fetchUser(let userId) = action else { return .next }

  dispatch(0, .setLoading(true))

  return .task { state in
    let user = try await api.fetchUser(id: userId)
    dispatch(0, .setUser(user), .setLoading(false))
  }
  // Se il task lancia un errore, viene automaticamente inviato al resolver chain
}
```

### Middleware deferred

`.deferred` sospende la pipeline in attesa del risultato asincrono. La closure è `async throws`, riceve lo state read-only e ritorna un `MiddlewareResumeExit` per continuare la pipeline:

```swift
let auth = AnyMiddleware<AppState, AppAction>(id: "auth") { context in
  guard case .login(let credentials) = context.action else { return .next }

  return .deferred { state in
    let token = try await authService.login(credentials)
    return .nextAs(.setToken(token))     // pipeline riprende con nuova action
    // Se il handler lancia un errore, viene automaticamente inviato al resolver chain
  }
}
```

Il `MiddlewareResumeExit` supporta gli stessi casi di `MiddlewareExit` eccetto `.task` e `.deferred` — non è possibile annidare sospensioni:

| MiddlewareResumeExit | Effetto |
|---|---|
| `.next` | La pipeline riprende con l'action originale |
| `.nextAs(action)` | La pipeline riprende con un'action diversa |
| `.resolve(error)` | L'errore viene inviato al resolver |
| `.exit(result)` | La pipeline termina |

Un `throw` nel handler equivale a `return .resolve(error)` — il framework cattura l'errore automaticamente e lo inoltra alla catena di resolver.

### Ordine di esecuzione

I middleware vengono eseguiti nell'ordine in cui sono forniti allo Store. Il primo middleware nell'array è il primo a vedere l'action:

```swift
Store(
  initialState: state,
  middlewares: [loggerMiddleware, authMiddleware, fetchMiddleware],  // log → auth → fetch
  ...
)
```

Se `authMiddleware` ritorna `.exit(.success)`, `fetchMiddleware` non viene mai eseguito.

---

## 9. Resolver

Il resolver gestisce gli errori che emergono dalla pipeline middleware. Viene invocato quando un middleware lancia un errore con `throw` o ritorna `.resolve(error)`.

### Protocollo

```swift
@MainActor
public protocol Resolver: Identifiable, Sendable {
  associatedtype S: ReduxState
  associatedtype A: ReduxAction
  var id: String { get }
  func run(_ context: ResolverContext<S, A>) -> ResolverExit<A>
}
```

### ResolverContext

| Proprietà | Tipo | Descrizione |
|---|---|---|
| `state` | `S.ReadOnly` | Vista read-only dello stato |
| `action` | `A` | L'action che ha generato l'errore |
| `error` | `SendableError` | L'errore catturato |
| `origin` | `String` | `id` del middleware che ha originato l'errore |
| `dispatch` | `@Sendable (UInt, A...) -> Void` | Dispatchia action di recovery |
| `args` | Tuple | `(state, action, error, origin, dispatch)` |

### ResolverExit

| Caso | Effetto |
|---|---|
| `.next` | Passa errore e action al prossimo resolver |
| `.nextAs(error, action)` | Passa errore e/o action modificati al prossimo resolver |
| `.reduce` | Short-circuit: esegue i reducer con l'action corrente |
| `.reduceAs(action)` | Short-circuit: esegue i reducer con un'action diversa |
| `.complete` | Errore gestito — nessuna ulteriore azione |
| `.drop` | Errore non gestibile — pipeline terminata |

### Flusso di risoluzione

Quando un errore entra nella catena di resolver:

```
Errore dal middleware "auth"
    │
    ▼
Resolver A
    ├── .complete    → errore gestito, stop
    ├── .reduce      → skip altri resolver, esegui reducer
    ├── .drop        → errore non gestibile, stop
    ├── .next        → passa a Resolver B
    └── .nextAs(e,a) → passa errore/action modificati a Resolver B
                            │
                            ▼
                       Resolver B
                            │ ...
                            ▼
                       Seed: errore non gestito viene loggato
```

Il primo resolver che non ritorna `.next` "vince" — i successivi non vengono eseguiti.

### Esempio: recovery da errore di rete

```swift
let networkResolver = AnyResolver<AppState, AppAction>(id: "network") { context in
  let (_, action, error, origin, dispatch) = context.args

  guard origin == "fetcher" else { return .next }    // non è un mio errore

  if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
    dispatch(0, .showOfflineAlert)
    return .complete                                  // gestito
  }

  dispatch(0, .showGenericError("\(error.localizedDescription)"))
  return .complete
}
```

### Esempio: redirect al reducer

In alcuni casi l'errore può essere convertito in un'action e passato ai reducer:

```swift
let fallbackResolver = AnyResolver<AppState, AppAction>(id: "fallback") { context in
  if case .fetchUser = context.action {
    return .reduceAs(.setUser(.placeholder))          // reducer riceve action di fallback
  }
  return .next
}
```

---

## 10. Pipeline di Dispatch

Questa sezione descrive il percorso completo di un'action dal dispatch alla UI.

### Diagramma completo

```
  any thread                          @MainActor
 ─────────────────────────────────────────────────────────────────────────

  store.dispatch(.increment)
       │
       ▼
 ┌───────────────────┐
 │    Dispatcher      │
 │  tryEnqueue()     │  rate limit check (Mutex)
 │                   │  ── limit raggiunto? ── scarta action ──▶ (noop)
 └────────┬──────────┘
          │ yield alla continuation
          ▼
 ┌───────────────────┐
 │   AsyncStream     │  FIFO buffer (capacity: 256)
 │   (action, comp?) │  action + completion opzionale
 └────────┬──────────┘
          │
 ─ ─ ─ ─ ┼ ─ ─ ─ ─ ─ ─ ─ ─ confine di isolamento ─ ─ ─ ─ ─ ─ ─ ─ ─ ─
          │
          ▼
 ┌───────────────────┐
 │  DispatchWorker   │  for await event in dispatcher.events
 │  (@MainActor)     │  processa un event alla volta (FIFO)
 └────────┬──────────┘
          │
          ▼
 ┌─────────────────────────────────────────────────────────────────────┐
 │                      MIDDLEWARE CHAIN (fold-based)                   │
 │                                                                     │
 │  L'action attraversa ogni middleware in ordine.                     │
 │  Il valore di ritorno di run() controlla il flusso.                 │
 │                                                                     │
 │  ┌─────────────┐   .next    ┌─────────────┐   .next    ┌────────┐ │
 │  │ Middleware A │──────────▶│ Middleware B │──────────▶│ seed:  │ │
 │  │   run()     │           │   run()     │           │reduce()│ │
 │  └──────┬──────┘           └──────┬──────┘           └────┬───┘ │
 │         │                         │                        │      │
 │         │ .nextAs(a2)             │ .task(body)            │      │
 │         │ ─▶ action modificata    │ ─▶ async + .next      │      │
 │         │    passa al successivo  │    (vedi sotto)        │      │
 │         │                         │                        │      │
 │         │ .exit(.success)         │ .deferred(handler)     │      │
 │         │ ─▶ pipeline terminata   │ ─▶ pipeline sospesa   │      │
 │         │    (forzata, ok)        │    (vedi sotto)        │      │
 │         │                         │                        │      │
 │         │ .exit(.failure(e))      │                        │      │
 │         │ ─▶ pipeline terminata   │                        │      │
 │         │    (forzata, errore)    │                        │      │
 │         │                         │                        │      │
 │         │ .resolve(error)         │                        │      │
 │         │ ─▶ resolver chain ──────┼────────────────────┐   │      │
 │         │                         │                    │   │      │
 │         │ throws                  │                    │   │      │
 │         │ ─▶ resolver chain ──────┼────────────────┐   │   │      │
 │         │                         │                │   │   │      │
 └─────────┼─────────────────────────┼────────────────┼───┼───┼──────┘
           │                         │                │   │   │
           │                         │                ▼   ▼   │
           │                         │  ┌──────────────────┐  │
           │                         │  │  RESOLVER CHAIN  │  │
           │                         │  │  (fold-based)    │  │
           │                         │  │                  │  │
           │                         │  │  Resolver A      │  │
           │                         │  │  ├ .complete ─▶ stop (gestito)
           │                         │  │  ├ .drop    ─▶ stop (scartato)
           │                         │  │  ├ .reduce  ─────────────┐
           │                         │  │  ├ .reduceAs(a2) ────────┤
           │                         │  │  ├ .next    ─▶ Resolver B│
           │                         │  │  └ .nextAs  ─▶ Resolver B│
           │                         │  │       │                  │
           │                         │  │       ▼                  │
           │                         │  │  Seed: log errore        │
           │                         │  │  non gestito (.drop)     │
           │                         │  └──────────────────┘       │
           │                         │                             │
           │                         │  short-circuit .reduce      │
           │                         │◀────────────────────────────┘
           │                         │
           │                         ▼
 ┌─────────┼─────────────────────────────────────────────────────────┐
 │         │             REDUCER CHAIN (forward order)               │
 │         │                                                         │
 │    ┌────┴──────┐    ┌───────────┐          ┌───────────┐         │
 │    │ Reducer 0 │───▶│ Reducer 1 │──▶ ... ─▶│ Reducer N │         │
 │    │ .next     │    │.defaultNxt│          │ .next     │         │
 │    └───────────┘    └───────────┘          └───────────┘         │
 │                                                                   │
 │    Ogni reducer muta lo state in-place.                           │
 │    I successivi vedono lo state già aggiornato.                   │
 └───────────────────────────────────────────────────────────────────┘
          │
          ▼
 ┌───────────────────┐
 │    Completion      │  event.completion?(state.readOnly)
 │    & Cleanup       │  dispatcher.decrease(id: action.id)
 └───────────────────┘
          │
          ▼
        (next event dal for-await loop)
```

### Path asincroni

Quando un middleware ritorna `.task` o `.deferred`, il lavoro asincrono si separa dal flusso principale:

```
 MIDDLEWARE                     PIPELINE PRINCIPALE           BACKGROUND
 ─────────────────────────────────────────────────────────────────────────

 .task { body }
    │                               │
    ├── lancia Task { body }  ──────┼─────────────▶  async body(readOnly)
    │                               │                    │
    └── .next (implicito)           │                    ├─ success ─▶ onLog(true)
        pipeline prosegue ─────────▶│                    │
                                    │                    └─ throws ──▶ onLog(false)
                                    │                                  resolveChain()
                                    ▼
                               reducer chain



 .deferred { state in ... }
    │                               │
    ├── Task { handler(readOnly) }──┼─────────────▶  async handler(readOnly)
    │                               │                    │
    └── pipeline SOSPESA            │                    ├─ return .next
        in attesa del risultato     │                    │     └▶ pipeline riprende
                                    │                    │        ─▶ next middleware
                                    │                    │
                                    │                    ├─ return .nextAs(a2)
                                    │                    │     └▶ pipeline riprende
                                    │                    │        con action modificata
                                    │                    │
                                    │                    ├─ return .resolve(e)
                                    │                    │     └▶ resolver chain
                                    │                    │
                                    │                    ├─ return .exit(result)
                                    │                    │     └▶ pipeline terminata
                                    │                    │
                                    │                    └─ throws
                                    │                          └▶ resolver chain (auto-catch)
                                    │
                                    ▼
                            (risultato riattiva la pipeline
                             sul MainActor via MainActor.run)
```

La differenza chiave:
- **`.task`** — la pipeline prosegue subito (`.next` implicito), il lavoro asincrono è indipendente. Se il task lancia un errore, viene inviato al resolver chain separatamente.
- **`.deferred`** — la pipeline si ferma finché il handler async non ritorna. Il valore di ritorno (`MiddlewareResumeExit`) determina come prosegue la pipeline. Un `throw` equivale a `.resolve(error)`.

### Costruzione della pipeline

La pipeline viene costruita **una sola volta** all'init dello Store, tramite `buildDispatchProcess()`. Tutte le dipendenze (state, readOnly, dispatcher, array dei componenti, onLog) vengono catturate come `let` locali — nessun riferimento a `self`, nessun ciclo di retain.

Le closure costruite, in ordine di dipendenza:

```
 buildDispatchProcess()
    │
    ├── 1. dispatch         Wrapper per dispatcher.tryEnqueue
    │                       Firma: @Sendable (UInt, A...) -> Void
    │                       Iniettato nei context di middleware e resolver
    │
    ├── 2. reduce           Itera tutti i reducer in forward order
    │                       Cattura: reducers, state, onLog
    │
    ├── 3. resolveChain     Fold dei resolver (reversed)
    │                       Seed: logga errore non gestito (.drop)
    │                       Cattura: resolvers, readOnly, dispatch, onLog
    │                       Può fare short-circuit verso reduce
    │
    ├── 4. runTask          Lancia .task fire-and-forget
    │                       Cattura: readOnly, onLog, resolveChain
    │                       Timing asincrono separato
    │
    ├── 5. runDeferredTask  Lancia .deferred con async handler + state access
    │                       Cattura: readOnly, onLog, resolveChain
    │                       Timing dal lancio al completamento (o throw)
    │
    └── 6. middlewareChain  Fold dei middleware (reversed) attorno a reduce
                            Entry point della pipeline
                            Gestisce tutti i casi di MiddlewareExit
                            Cattura: middlewares, readOnly, dispatch,
                                     reduce, resolveChain, runTask,
                                     runDeferredTask, onLog
```

---

## 11. Rate Limiting

Il rate limiting limita quante action con lo stesso `id` possono essere in coda contemporaneamente. Utile per evitare flood da input rapido (scroll, digitazione, tap ripetuti).

### Come funziona

Ogni action ha un `id` (derivato dal case enum con `@CaseID`). Il `Dispatcher` mantiene un contatore per ogni `id` attivo, protetto da `Mutex`:

1. **Enqueue**: `tryEnqueue` controlla se il contatore per quell'`id` è sotto il limite. Se sì, incrementa e accoda. Se no, scarta l'action.
2. **Pipeline completa**: `decrease` decrementa il contatore. Quando raggiunge zero, la chiave viene rimossa.

### Utilizzo

Il parametro `maxDispatchable` è disponibile su tutti i metodi di dispatch:

```swift
// Al massimo 1 action .fetchData in coda alla volta
store.dispatch(maxDispatchable: 1, .fetchData)

// 0 = nessun limite (default)
store.dispatch(.increment)

// Anche con completion
store.dispatch(maxDispatchable: 2, .search(query)) { state in
  print("Results: \(state.searchResults.count)")
}

// Anche nel dispatch dal middleware
let middleware = AnyMiddleware<S, A>(id: "m") { context in
  let (_, dispatch, _) = context.args
  dispatch(1, .fetchData)          // primo parametro = maxDispatchable
  return .next
}
```

### Throttled dispatch con risultato

`dispatchWithResult` ritorna immediatamente lo stato corrente se l'action viene throttled:

```swift
let state = await store.dispatchWithResult(maxDispatchable: 1, .fetchData)
// Se throttled: state == stato corrente, pipeline non eseguita
// Se accodato: state == stato dopo la pipeline
```

---

## 12. Logging e Diagnostica

Il parametro `onLog` dello Store riceve eventi per ogni step della pipeline, con timing automatico.

### Store.Log

```swift
public enum Log: Sendable {
  case middleware(String, A, Duration, Bool)
  case reducer(String, A, Duration, ReducerExit)
  case resolver(String, A, Duration, ResolverExit<A>, SendableError)
  case store(String)
}
```

| Caso | Parametri | Quando |
|---|---|---|
| `.middleware` | id, action, elapsed, succeeded | Dopo ogni middleware (sync) |
| `.middleware` | id, action, elapsed, succeeded | Dopo completamento di `.task` o `resume` di `.deferred` (async) |
| `.reducer` | id, action, elapsed, exit | Dopo ogni reducer |
| `.resolver` | id, action, elapsed, exit, error | Dopo ogni resolver |
| `.store` | message | Messaggi diagnostici dello store |

Il timing usa `ContinuousClock` — il timestamp viene catturato prima dell'esecuzione e la `Duration` viene calcolata al ritorno.

Per `.task` e `.deferred`, il timing async è separato: copre la durata dal lancio al completamento (o resume).

### Esempio di formatter

```swift
let store = Store(
  initialState: AppState(),
  middlewares: [...],
  resolvers: [...],
  reducers: [...],
  onLog: { log in
    switch log {
    case let .middleware(id, action, elapsed, true):
      print("[MW] \(id) ✓ \(action.id) (\(elapsed))")
    case let .middleware(id, action, elapsed, false):
      print("[MW] \(id) ✗ \(action.id) (\(elapsed))")
    case let .reducer(id, action, elapsed, exit):
      print("[RD] \(id) \(exit) \(action.id) (\(elapsed))")
    case let .resolver(id, action, elapsed, exit, error):
      print("[RS] \(id) \(exit) \(action.id) error=\(error) (\(elapsed))")
    case let .store(msg):
      print("[ST] \(msg)")
    }
  }
)
```

`onLog` è `@Sendable` — sicuro da chiamare da qualsiasi contesto.

---

## 13. Pattern Avanzati

### Composizione di più middleware

I middleware vengono eseguiti in ordine. I primi nell'array vedono l'action per primi e possono modificarla per i successivi:

```swift
let store = Store(
  initialState: state,
  middlewares: [
    logger,        // logga tutte le action in arrivo
    validator,     // blocca action invalide o lancia errori
    transformer,   // normalizza/trasforma le action
    sideEffect,    // esegue chiamate API, timer, etc.
  ],
  resolvers: [networkResolver, fallbackResolver],
  reducers: [userReducer, uiReducer],
  onLog: { ... }
)
```

### Resolver con short-circuit al reducer

Quando un resolver può convertire un errore in un'action significativa, usa `.reduce` o `.reduceAs` per saltare direttamente ai reducer:

```swift
let cacheResolver = AnyResolver<AppState, AppAction>(id: "cache") { context in
  if case .fetchData = context.action,
     let cached = CacheManager.shared.get("data") {
    return .reduceAs(.setData(cached))      // reducer riceve dati dalla cache
  }
  return .next
}
```

### Type Aliases

Il framework espone type alias per le firme comuni delle closure:

```swift
Dispatch<A>              = @Sendable (UInt, A...) -> Void
MiddlewareHandler<S, A>  = @MainActor (MiddlewareContext<S, A>) throws -> MiddlewareExit<S, A>
StatedHandler<C, S, A>   = @MainActor (C, MiddlewareContext<S, A>) throws -> MiddlewareExit<S, A>
ReducerHandler<S, A>     = @MainActor (ReducerContext<S, A>) -> ReducerExit
ResolverHandler<S, A>    = @MainActor (ResolverContext<S, A>) -> ResolverExit<A>
DispatchProcess<S, A>    = @MainActor (S.ReadOnly, A) -> Void
EventCompletion<S>       = @Sendable (S.ReadOnly) -> Void
LogHandler<S, A>         = @Sendable (Store<S, A>.Log) -> Void
```

---

## 14. Riferimento Rapido

### Protocolli

| Protocollo | Vincoli | Ruolo |
|---|---|---|
| `ReduxAction` | `Identifiable`, `Equatable`, `Sendable` | Action dispatchabile |
| `ReduxState` | `@MainActor`, `AnyObject`, `Observable`, `Sendable` | State mutabile |
| `ReduxReadOnlyState` | `@MainActor`, `AnyObject`, `Observable`, `Sendable` | Proiezione read-only |
| `Middleware` | `@MainActor`, `Identifiable`, `Sendable` | Side effects |
| `Reducer` | `@MainActor`, `Identifiable`, `Sendable` | Mutazione pura |
| `Resolver` | `@MainActor`, `Identifiable`, `Sendable` | Error recovery |

### Tipi concreti

| Tipo | Descrizione |
|---|---|
| `Store<S, A>` | Hub centrale: state + pipeline + dispatch |
| `AnyMiddleware<S, A>` | Type-erased middleware (closure o conformer) |
| `AnyReducer<S, A>` | Type-erased reducer (closure) |
| `AnyResolver<S, A>` | Type-erased resolver (closure o conformer) |

### Exit enums

| Enum | Restituito da | Casi |
|---|---|---|
| `MiddlewareExit<S, A>` | `Middleware.run()` | `.next`, `.nextAs`, `.resolve`, `.exit`, `.task`, `.deferred` |
| `MiddlewareResumeExit<A>` | `MiddlewareResume` | `.next`, `.nextAs`, `.resolve`, `.exit` |
| `ReducerExit` | `Reducer.reduce` | `.next`, `.defaultNext` |
| `ResolverExit<A>` | `Resolver.run()` | `.next`, `.nextAs`, `.reduce`, `.reduceAs`, `.complete`, `.drop` |

### Context

| Context | Proprietà |
|---|---|
| `MiddlewareContext<S, A>` | `state` (ReadOnly), `action`, `dispatch` (nonisolated) |
| `ReducerContext<S, A>` | `state` (mutabile), `action` |
| `ResolverContext<S, A>` | `state` (ReadOnly), `action`, `error`, `origin`, `dispatch` (nonisolated) |

Tutti i context sono `@frozen @MainActor struct`, `Sendable`, con `.args` per destructuring.

### Dispatch API

| Metodo | Isolation | Ritorno |
|---|---|---|
| `dispatch(maxDispatchable:_:)` | `nonisolated` | `Void` (variadic `A...`) |
| `dispatch(maxDispatchable:_:completion:)` | `nonisolated` | `Bool` (throttled?) |
| `dispatchWithResult(maxDispatchable:_:)` | `@MainActor async` | `S.ReadOnly` |
| `bind(_:maxDispatchable:_:)` | `@MainActor` | `Binding<T>` |
