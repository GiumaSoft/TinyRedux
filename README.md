# TinyRedux

## Summary

**TinyRedux** is a small-footprint library, strongly inspired by ReduxJS, written in pure Swift.

## Overview

**TinyRedux** offers a significant improvement over traditional MVC and MVVM architectures.

`Store` centralizes global state management and removes the need to pass data across multiple ViewModels, which can become a heavy task when evolving consolidated logic.

**TinyRedux** adopts a **Supervised Redux Model** where middleware, resolver, and reducer cooperate in the same dispatch flow with distinct responsibilities:

- `Middleware` orchestrates async operations and side effects across the app. 

- `Resolver` supervises errors raised during that flow and applies remediation strategies before the action continues. 

- `Reducer` applies deterministic state transitions.

This separation keeps the architecture clean and aligns with `SOLID` principles thanks to composable abstractions for middleware, resolver, and store processing.

![TinyRedux flow diagram](https://github.com/GiumaSoft/TinyRedux/blob/main/ReduxFlow.gif)

## Examples


### 1. AppState

Example of declaration

 --------------
 
```swift
import Observation
import SwiftUI
import TinyRedux

@MainActor
@Observable
final class AppState : ReduxState {
  @MainActor
  final class ReadOnlyAppState: ReduxReadOnlyState {
    private unowned let state: AppState

    init(_ state: AppState) {
      self.state = state
    }

    var counter: Int { state.counter }
  }

  var counter: Int

  @ObservationIgnored
  lazy var readOnly = ReadOnlyAppState(self)

  init(
    counter: Int
  ) {
    self.counter = counter
  }

  convenience init() {
    self.init(
      counter: 0
    )
  }
}
```

### 2. AppAction

Example of declaration

 --------------
 
```swift
import Observation
import SwiftUI
import TinyRedux

enum AppActions : ReduxAction {
  case inc(Int)
  case dec(Int)

  var id: Int {
    switch self {
    case .inc: 10
    case .dec: 20
    }
  }

  var description: String {
    switch self {
    case .inc: ".inc"
    case .dec: ".dec"
    }
  }

  var debugDescription: String {
    switch self {
    case .inc(let value): ".inc by \(value) step."
    default:
      description
    }
  }
}
```

### 3. Middleware

Example of declaration

 --------------
 
```swift
import Observation
import SwiftUI
import TinyRedux

let testMiddleware = AnyMiddleware<AppState, AppActions>(
  StatedMiddleware(id: "testMiddlware", coordinator: TestMiddlewareCoordinator()) { coordinator, >context in
    let (dispatch, resolve, task, next, action) = context.args

    switch action {
    case .inc(let value):
      task { state in
        try await Task.sleep(nanoseconds: 60 * 60 * 1_000_000_000)
        dispatch(.dec(value))
      }

      break
    case .dec(let value):
      // Test async operations then break or return depending on you want to
      // retain/delay/interrupt the next execution.
      break
    }

    try next(action)
  }
)
```

### 4. Resolver

Example of declaration

 --------------
 
```swift
import Observation
import SwiftUI
import TinyRedux

let testResolver = AnyResolver<AppState, AppActions>(id: "testResolver") { context in
  let (state, dispatch, action, error, origin) = context.args

  switch (error, action) {
  case (_, .inc):
    break
  case (_, .dec):
    break
  }
}
```

### 5. Reducer

Example of declaration

 --------------
 
```swift
import Observation
import SwiftUI
import TinyRedux

let testReducer = AnyReducer<AppState, AppActions>(id: "testReducer") { context in
  let (state, action) = context.args

  switch action {
  case .inc(let value):
    state.counter += value
  case .dec(let value):
    state.counter -= value
  }
}
```

### 6.Store

Example of declaration

 --------------
 
```swift
import Observation
import SwiftUI
import TinyRedux

let store = Store.main

extension Store where State == AppState, Action == AppActions {
  static let main = Store<AppState, AppActions>(
    initialState: AppState(),
    middlewares: [testMiddleware],
    resolvers: [testResolver],
    reducers: [testReducer]
  )
}
```
