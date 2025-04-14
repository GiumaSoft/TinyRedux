//


import Foundation
import TinyRedux


extension GlobalValues {
  var mainStore: Store<AppState, AppActions> { GlobalValues.mainStore }
  var sample01Store: SubStore<Sample01State, Sample01Actions, AppState, AppActions> { GlobalValues.sample01Store }
  var sample02Store: SubStore<Sample02State, Sample02Actions, AppState, AppActions> { GlobalValues.sample02Store }
  var sample03Store: SubStore<Sample03State, Sample03Actions, AppState, AppActions> { GlobalValues.sample03Store }
}

extension GlobalValues {
  static let mainStore = Store<AppState, AppActions>(
    initialState: AppState(),
    reducers: [
      .logger(
        .reduce(
          Reducer(sample01Reducer, toState: \.sample01, toAction: \.sample01),
          Reducer(sample02Reducer, toState: \.sample02, toAction: \.sample02),
          Reducer(sample03Reducer, toState: \.sample03, toAction: \.sample03)
        )
      )
    ],
    middlewares: [
      AnyMiddleware(sample02Middleware, toState: \.sample02, toAction: \.sample02, toGlobalAction: { .sample02($0) })
    ]
  )
  
  static let sample01Store = SubStore<Sample01State, Sample01Actions, AppState, AppActions>(
    initialStore: mainStore,
    toLocalState: \.sample01,
    toGlobalAction: { .sample01($0) }
  )
  
  static let sample02Store = SubStore<Sample02State, Sample02Actions, AppState, AppActions>(
    initialStore: mainStore,
    toLocalState: \.sample02,
    toGlobalAction: { .sample02($0) }
  )
  
  static let sample03Store = SubStore<Sample03State, Sample03Actions, AppState, AppActions>(
    initialStore: mainStore,
    toLocalState: \.sample03,
    toGlobalAction: { .sample03($0) }
  )
}

