//


import Foundation
import TinyRedux


@MainActor
extension GlobalValues {
  var mainStore: Store<AppState, AppActions> { .main }
}

@MainActor
extension Store where S == AppState, A == AppActions {
  static let main = Store.sharedInstance(
    initialState: AppState(),
    middlewares: [
      Middleware(sample02Middleware),
      sample04Middleware
    ],
    resolvers: [
      sample04Resolver
    ],
    reducers: [
      sample01Reducer,
      sample02Reducer,
      sample03Reducer,
      sample04Reducer
    ],

    onLog: { message in
      print(message)
    }
  )
}
