//


import Foundation
import TinyRedux


@MainActor
extension GlobalValues {
  var mainStore: Store<AppState, AppActions> { GlobalValues.mainStore }
  var sample01Store: SubStore<AppState, Sample01Actions, AppState, AppActions> { GlobalValues.sample01Store }
  var sample02Store: SubStore<AppState, Sample02Actions, AppState, AppActions> { GlobalValues.sample02Store }
  var sample03Store: SubStore<AppState, Sample03Actions, AppState, AppActions> { GlobalValues.sample03Store }
}

@MainActor
extension GlobalValues {
  static let mainStore = Store<AppState, AppActions>(
    initialState: AppState(),
    middlewares: [
      Middleware(sample02Middleware, toState: \.self, toAction: \.sample02, toGlobalAction: { .sample02($0) })
    ],
    reducers: [
      .logger(
        .reduce(
          Reducer(sample01Reducer, toState: \.self, toAction: \.sample01),
          Reducer(sample02Reducer, toState: \.self, toAction: \.sample02),
          Reducer(sample03Reducer, toState: \.self, toAction: \.sample03)
        )
      )
    ]
  )
  
  static let sample01Store = SubStore<AppState, Sample01Actions, AppState, AppActions>(
    initialStore: mainStore,
    toLocalState: \.self,
    toGlobalAction: { .sample01($0) }
  )
  
  static let sample02Store = SubStore<AppState, Sample02Actions, AppState, AppActions>(
    initialStore: mainStore,
    toLocalState: \.self,
    toGlobalAction: { .sample02($0) }
  )
  
  static let sample03Store = SubStore<AppState, Sample03Actions, AppState, AppActions>(
    initialStore: mainStore,
    toLocalState: \.self,
    toGlobalAction: { .sample03($0) }
  )
}

