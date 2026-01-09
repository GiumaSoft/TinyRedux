//

import XCTest
@testable import Example
@testable import TinyRedux

@MainActor
final class ExampleTests: XCTestCase {
  func testSample02ReducerTogglesTimerFlag() {
    let state = AppState()
    let store = Store(
      initialState: state,
      middlewares: [],
      resolvers: [],
      reducers: [sample02Reducer]
    )

    store.dispatch(.startAutoCounter)
    XCTAssertTrue(state.timerIsRunning)

    store.dispatch(.stopAutoCounter)
    XCTAssertFalse(state.timerIsRunning)
  }

  func testSample04ReducerUpdatesEffectMessage() {
    let state = AppState()
    let store = Store(
      initialState: state,
      middlewares: [],
      resolvers: [],
      reducers: [sample04Reducer]
    )
    let message = "Effect done"

    store.dispatch(.setEffectMessage(message))

    XCTAssertEqual(state.effectMessage, message)
  }
}
