//


import Foundation
import TinyRedux


@MainActor
extension GlobalValues {
  var mainStore: Store<AppState, AppActions> { GlobalValues.mainStore }
}

@MainActor
extension GlobalValues {
  static let mainStore = Store<AppState, AppActions>.sharedInstance(
    initialState: AppState(),
    middlewares: [
      Middleware(sample02Middleware)
    ],
    reducers: [
      sample01Reducer,
      sample02Reducer,
      sample03Reducer
    ],
    onException: { error in
      print(error.localizedDescription)
    },
    onLog: { message in
      print(message)
    }
  )
}

