//


import Foundation
import TinyRedux


@MainActor
extension GlobalValues {
  var mainStore: Store<AppState, AppActions> { .main }
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
    onException: { error in
      
    },
    onLog: { message in
      print(message)
    }
  )
}
