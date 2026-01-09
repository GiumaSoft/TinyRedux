//

import Testing
@testable import Example
@testable import TinyRedux


private struct _WaitSnapshot: ReduxStateSnapshot {
  typealias S = AppState
  @MainActor init(state: AppState.ReadOnly) {}
}


@MainActor
struct ExampleTests {
  @Test func sample02ReducerTogglesTimerFlag() async {
    let state = AppState()
    let store = Store(
      initialState: state,
      middlewares: [],
      resolvers: [],
      reducers: [sample02Reducer]
    )

    _ = await store.dispatch(.startAutoCounter, snapshot: _WaitSnapshot.self)
    #expect(state.timerIsRunning == true)

    _ = await store.dispatch(.stopAutoCounter, snapshot: _WaitSnapshot.self)
    #expect(state.timerIsRunning == false)
  }

  @Test func sample04ReducerUpdatesEffectMessage() async {
    let state = AppState()
    let store = Store(
      initialState: state,
      middlewares: [],
      resolvers: [],
      reducers: [sample04Reducer]
    )
    let message = "Effect done"

    _ = await store.dispatch(.setEffectMessage(message), snapshot: _WaitSnapshot.self)

    #expect(state.effectMessage == message)
  }
}
