//


import Foundation
import TinyRedux


extension ExampleApp {
  static let defaultStore: Store<AppState, AppActions> = Store(
    initialState: AppState(),
    reducers: [
      .logger(
        .reduce(
          sample01Reducer.lift(toState: \.sample01State, toAction: \.sample01),
          sample02Reducer.lift(toState: \.sample02State, toAction: \.sample02),
          sample03Reducer.lift(toState: \.sample03State, toAction: \.sample03)
        )
      )
    ],
    middlewares: [
      sample02Middleware.lift(toState: \.sample02State, toAction: \.sample02, toGlobalAction: { .sample02($0) })
    ]
  )
  
  static let sample01Store = SubStore<Sample01State, Sample01Actions, AppState, AppActions>(
    initialStore: defaultStore,
    toLocalState: \.sample01State,
    toGlobalAction: { .sample01($0) }
  )
  
  static let sample02Store = SubStore<Sample02State, Sample02Actions, AppState, AppActions>(
    initialStore: defaultStore,
    toLocalState: \.sample02State,
    toGlobalAction: { .sample02($0) }
  )
  
  static let sample03Store = SubStore<Sample03State, Sample03Actions, AppState, AppActions>(
    initialStore: defaultStore,
    toLocalState: \.sample03State,
    toGlobalAction: { .sample03($0) }
  )
}

