//
//  Composition root: maps the external CounterFeature module onto the app, and builds
//  the store. The SAME mapping drives both the reducer lift and the view's slice.
//

import CounterFeature
import TinyRedux


@MainActor
enum AppModules
{
  // `.scattered`: projects the module's flat `count` onto the app-owned `counter: Int`
  // via a ReduxBinding. The module stays ignorant of AppState.
  static let counterMap = ReduxModuleMap<CounterFeatureState, CounterFeatureActions, AppState, AppActions>
    .scattered(
      state: { app in
        CounterFeatureState(count: ReduxBinding {
          app.counter
        } set: {
          app.counter = $0
        })
      },
      action: \.counter,
      toRootAction: AppActions.counter
    )

  static func makeStore() -> ReduxStore<AppState, AppActions>
  {
    ReduxStore(
      initialState: AppState(),
      reducers: [
        AnyReduxReducer(counterFeatureReducer, moduleMap: counterMap)   // lift the module's reducer via the mapping
      ],
      onLog: AppLog.handle                                        // structured logs → os.Logger
    )
  }
}
