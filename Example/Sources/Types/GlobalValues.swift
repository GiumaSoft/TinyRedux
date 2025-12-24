//


import Foundation
import TinyRedux


@MainActor
extension GlobalValues {
  var mainStore: Store<AppState, AppActions> { Store.main }
}

@MainActor
extension Store where S == AppState, A == AppActions {
  static let main = Store(
    initialState: AppState(),
    middlewares: [Middleware(sample02Middleware)],
    reducers: [
      sample01Reducer,
      sample02Reducer,
      sample03Reducer
    ],
    onLog: { message in
      print(message)
    }
  )
}
