![TinyRedux flow diagram](https://github.com/GiumaSoft/TinyRedux/blob/main/ReduxFlow.gif)

# TinyRedux

## Summary

**TinyRedux** is a small-footprint state-management library, strongly inspired by ReduxJS, written in pure Swift 6 for SwiftUI on iOS and macOS.

## Overview

**TinyRedux** offers a significant improvement over traditional MVC and MVVM architectures.

`ReduxStore` centralizes global state management and removes the need to pass data across multiple ViewModels, which can become a heavy task when evolving consolidated logic.

**TinyRedux** adopts a **Supervised Redux Model** where middleware, resolver, and reducer cooperate in the same dispatch flow with distinct responsibilities:

- `Middleware` orchestrates async operations and side effects across the app.

- `Resolver` supervises errors raised during that flow and applies remediation strategies before the action continues.

- `Reducer` applies deterministic state transitions — the only component allowed to write state.

This separation keeps the architecture clean and aligns with `SOLID` principles thanks to composable abstractions for middleware, resolver, and store processing.

### Highlights

- **Native SwiftUI integration** — `ReduxStore` is `@Observable` and `@dynamicMemberLookup`.
- **Thread-safe dispatch** from any isolation via `nonisolated dispatch`.
- **Strict Concurrency** — built and shipped under the Swift 6 language mode.
- **Macros** (`@ReduxState`, `@ReduxMappedState`, `@ReduxAction`) that erase boilerplate.
- **Modules & slices** — compose feature modules onto a root store with `.linear` or `.scattered` mapping; a feature View depends only on `any ReduxModule<LS, LA>`.
- **State→Action subscriptions** registered from middleware.
- **Snapshot API** — `await` a JSON-encoded state projection at a pipeline terminal, or stream encoded frames with `SnapshotSpec`.
- **Structured logging** — a typed `ReduxLog` stream, zero-cost when no handler is attached.
- **Backpressure** — an unbounded, replayable queue with opt-in per-dispatch rate control (`DispatchRateLimit`) and high-frequency diagnostics.

### Requirements

- Swift 6.0 toolchain
- iOS 18+ / macOS 15+
- Dependency: [`swift-syntax`](https://github.com/swiftlang/swift-syntax) (for the macros)

### Installation

Swift Package Manager — add the dependency to your `Package.swift`:

```swift
.package(url: "https://github.com/GiumaSoft/TinyRedux", from: "1.0.23")
```

## Examples

### 1. State

A root state is an `@Observable` reference type that conforms to `ReduxState`. The
`@ReduxState` macro generates the `ReadOnly` projection, the `readOnly` property, and
the designated initializer.

```swift
import TinyRedux

@ReduxState
@Observable
@MainActor
final class AppState: ReduxState {
  var counter: Int
  var isLoggedIn: Bool

  nonisolated convenience init() {
    self.init(counter: 0, isLoggedIn: false)
  }
}
```

### 2. Action

Actions are a flat `enum`. `@ReduxAction` synthesizes `id` from the case names; identity
is case-only (associated values are ignored).

```swift
import TinyRedux

@ReduxAction
enum AppActions: ReduxAction {
  case increment        // synchronous — handled by the reducer, ignored by the middleware
  case decrement
  case delayedInc       // asynchronous — handled by the middleware, never reduced directly
  case delayedDec
  case login            // asynchronous and CAN FAIL — its error is handled by the resolver
  case setLoggedIn(Bool)
}
```

### 3. Reducer

The reducer is the only writer. It mutates the state in place and returns a
`ReduxReducerExit` (`.next`, `.done`, or `.defaultNext`).

```swift
import TinyRedux

let mainReducer = AnyReduxReducer<AppState, AppActions>(id: "mainReducer") { context in
  let (state, action) = context.args

  switch action {
  case .increment:
    state.counter += 1
    return .next
  case .decrement:
    state.counter -= 1
    return .next
  case .setLoggedIn(let value):
    state.isLoggedIn = value
    return .next
  default:
    return .defaultNext      // .delayedInc / .delayedDec / .login are handled by the middleware
  }
}
```

### 4. Middleware

Middleware intercepts actions before the reducers, runs async effects, and may dispatch
new actions. It reads state (read-only by convention) and never mutates it. Returning
control flow is expressed with `MiddlewareExit`.

Here `increment`/`decrement` bypass the middleware entirely (`.defaultNext`) and flow
straight to the reducer — they stay synchronous. The async work lives in `delayedInc` /
`delayedDec`: a `.deferred` effect suspends the chain, waits, then resumes it as the
matching sync action via `.nextAs(_)`.

```swift
import TinyRedux

let counterMiddleware = AnyMiddleware<AppState, AppActions>(id: "counter") { context in
  switch context.action {
  case .delayedInc:
    return .deferred { _ in             // suspends the chain until it returns
      try await Task.sleep(for: .seconds(1))
      return .nextAs(.increment)        // resume the chain as .increment → reducer
    }
  case .delayedDec:
    return .deferred { _ in
      try await Task.sleep(for: .seconds(1))
      return .nextAs(.decrement)
    }
  default:
    return .defaultNext                 // increment/decrement pass straight through to the reducer
  }
}
```

### 5. Resolver

The resolver is the error branch: it handles errors raised in the pipeline (a middleware
`throw`, a failing effect, or an explicit `.exit(.resolve(_))`). Here the `login` effect can
throw; the resolver decides recovery via `ResolverExit` — `.exit(.reduce)`,
`.exit(.reduceAs(_))`, `.exit(.done)`, or `.exit(.fail(_))`.

```swift
import TinyRedux

// Login is the thing that can fail: the async effect throws on bad credentials,
// and the framework routes that error to the resolver.
let authMiddleware = AnyMiddleware<AppState, AppActions>(id: "auth") { context in
  switch context.action {
  case .login:
    return .deferred { _ in
      try await AuthService.login()       // may throw AuthError → routed to the resolver
      return .nextAs(.setLoggedIn(true))  // success → resume the chain into the reducer
    }
  default:
    return .defaultNext
  }
}

let authResolver = AnyResolver<AppState, AppActions>(id: "authResolver") { context in
  switch context.error {
  case is AuthError:
    return .exit(.reduceAs(.setLoggedIn(false)))   // recover: reduce a known logged-out state
  default:
    return .defaultNext                            // not mine → next resolver (default → fail)
  }
}
```

### 6. Store

`reducers` is required; `middlewares`, `resolvers`, `options`, and `onLog` are optional.
The pipeline is live as soon as the store is created — there is no `start()`.

```swift
import TinyRedux

extension ReduxStore where S == AppState, A == AppActions {
  static let main = ReduxStore(
    initialState: AppState(),
    reducers: [mainReducer],
    middlewares: [counterMiddleware, authMiddleware],
    resolvers: [authResolver]
  )
}

let store = ReduxStore.main
store.dispatch(.increment)              // nonisolated — any isolation
```

### 7. SwiftUI

`ReduxStore` reads via `@dynamicMemberLookup` and writes via `dispatch`.

```swift
import SwiftUI
import TinyRedux

struct CounterView: View {
  let store: ReduxStore<AppState, AppActions>

  var body: some View {
    VStack {
      Text("Counter: \(store.counter)")
      HStack {                                       // synchronous
        Button("−") { store.dispatch(.decrement) }
        Button("+") { store.dispatch(.increment) }
      }
      HStack {                                       // asynchronous (1s delay via middleware)
        Button("− later") { store.dispatch(.delayedDec) }
        Button("+ later") { store.dispatch(.delayedInc) }
      }

      Divider()

      Text(store.isLoggedIn ? "Logged in" : "Logged out")
      Button("Log in") { store.dispatch(.login) }    // async + can fail → resolver
    }
  }
}
```

### 8. Modules & slices

A feature module is written against its own local state/action and never imports the host
app. A `ReduxModuleMap` plugs it into the root store, and the **same map** drives both the
reducer lift and the View's slice.

```swift
// ── In the feature framework (imports only TinyRedux) ──
@ReduxAction
public enum CounterFeatureActions: ReduxAction {
  case increment
  case decrement
}

public struct CounterFeatureView: View {
  let module: any ReduxModule<CounterFeatureState, CounterFeatureActions>
  // reads module.state, writes module.dispatch(...)
}

// ── In the app: compose the module's actions into AppActions ──
@ReduxAction
enum AppActions: ReduxAction {
  // … the app's own cases (increment, decrement, login, …) …
  case counter(CounterFeatureActions)            // the module's actions, nested as a case
}

extension AppActions {
  var counter: CounterFeatureActions? {          // the `\.counter` extractor the map uses
    guard case let .counter(action) = self else { return nil }
    return action
  }
}

// ── In the app: the composition root (same map drives reducer lift + slice) ──
let counterMap = ReduxModuleMap<CounterFeatureState, CounterFeatureActions, AppState, AppActions>
  .scattered(
    state: { app in CounterFeatureState(count: ReduxBinding { app.counter } set: { app.counter = $0 }) },
    action: \.counter,                           // AppActions → CounterFeatureActions?
    toRootAction: AppActions.counter             // CounterFeatureActions → AppActions
  )

let store = ReduxStore(
  initialState: AppState(),
  reducers: [AnyReduxReducer(counterFeatureReducer, moduleMap: counterMap)]
)

// In a View:
CounterFeatureView(module: store.slice(counterMap))
```

## Documentation

- [**DOCUMENT.md**](DOCUMENT.md) — User Guide: concepts, API walkthrough, tutorials, and patterns.
- [**ARCHITECTURE.md**](ARCHITECTURE.md) — Technical Specification: internals of the store, worker, dispatcher, and pipeline.

## License

See [LICENSE](LICENSE).
