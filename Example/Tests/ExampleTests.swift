//

import Testing
@testable import Example
@testable import TinyRedux

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

    _ = await store.dispatchWithResult(.startAutoCounter)
    #expect(state.timerIsRunning == true)

    _ = await store.dispatchWithResult(.stopAutoCounter)
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

    _ = await store.dispatchWithResult(.setEffectMessage(message))

    #expect(state.effectMessage == message)
  }
}
