//


import Foundation
import TinyRedux


@MainActor
extension GlobalValues {
  var mainStore: Store<AppState, AppActions> { .main }
}

@MainActor
extension Store where State == AppState, Action == AppActions {
  static let main = Store(
    initialState: AppState(),
    middlewares: [
      AnyMiddleware(sample02Middleware),
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
    onLog: { logItem in
      print(reduxLogFormatter(logItem))
    }
  )
}
