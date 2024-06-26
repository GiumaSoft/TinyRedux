//


import Foundation
import TinyRedux


extension ExampleApp {
  static let defaultStore: Store<AppState, AppActions> = Store(
    initialState: AppState(),
    reducer: logger(
      combine(
        pullback(timerReducer, toState: \.timerState, toAction: \.timer),
        pullback(counterReducer, toState: \.counterState, toAction: \.counter)
      ),
      excludedActions: [
        .counter(.decreaseCounter)
      ]
    ),
    middlewares: [
      pullback(timerMiddleware, toState: \.timerState, toAction: \.timer, toGlobalAction: { .timer($0) }),
      pullback(counterMiddleware, toState: \.counterState, toAction: \.counter, toGlobalAction: { .counter($0) })
    ]
  )
  
  static let timerStore: SubStore<AppState, AppActions, TimerState, TimerActions> = SubStore(
    initialStore: defaultStore,
    toLocalState: \.timerState,
    toGlobalAction: { .timer($0) }
  )
  
  static let counterStore: SubStore<AppState, AppActions, CounterState, CounterActions> = SubStore(
    initialStore: defaultStore,
    toLocalState: \.counterState,
    toGlobalAction: { .counter($0) }
  )
  
  static let bindingStore: SubStore<AppState, AppActions, BindingState, BindingActions> = SubStore(
    initialStore: defaultStore,
    toLocalState: \.bindingState,
    toGlobalAction: { .binding($0) }
  )
}

