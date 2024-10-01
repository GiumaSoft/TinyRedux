//


import Foundation
import TinyRedux


extension ExampleApp {
  static let defaultStore: Store<AppState, AppActions> = Store(
    initialState: AppState(),
    reducer: logger(
      combine(
        pullback(sample01Reducer, toState: \.sample01State, toAction: \.sample01),
        pullback(sample02Reducer, toState: \.sample02State, toAction: \.sample02),
        pullback(sample03Reducer, toState: \.sample03State, toAction: \.sample03)
      ),
      excludedActions: [
        .sample02(.decrease)
      ]
    ),
    middlewares: [
      pullback(sample02Middleware, toState: \.sample02State, toAction: \.sample02, toGlobalAction: { .sample02($0) })
    ]
  )
  
  static let sample01Store: SubStore<AppState, AppActions, Sample01State, Sample01Actions> = SubStore(
    initialStore: defaultStore,
    toLocalState: \.sample01State,
    toGlobalAction: { .sample01($0) }
  )
  
  static let sample02Store: SubStore<AppState, AppActions, Sample02State, Sample02Actions> = SubStore(
    initialStore: defaultStore,
    toLocalState: \.sample02State,
    toGlobalAction: { .sample02($0) }
  )
  
  static let sample03Store: SubStore<AppState, AppActions, Sample03State, Sample03Actions> = SubStore(
    initialStore: defaultStore,
    toLocalState: \.sample03State,
    toGlobalAction: { .sample03($0) }
  )
}

