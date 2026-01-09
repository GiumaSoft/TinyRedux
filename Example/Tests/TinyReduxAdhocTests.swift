//

import XCTest
@testable import Example
@testable import TinyRedux

@MainActor
final class TinyReduxAdhocTests: XCTestCase {
  func testSample03ReducerUpdatesHeader() {
    let state = AppState()
    let store = Store(
      initialState: state,
      middlewares: [],
      resolvers: [AnyResolver(id: "resolver") { context in
        XCTFail("Unexpected error: \(context.error)")
      }],
      reducers: [sample03Reducer]
    )
    let newHeader = "Test Header"

    store.dispatch(.setHeader(newHeader))

    XCTAssertEqual(state.header, newHeader)
  }

  func testCompleteEmitsReducerLog() {
    let state = AppState()
    var logs: [Store<AppState, AppActions>.Log] = []
    let store = Store(
      initialState: state,
      middlewares: [],
      resolvers: [AnyResolver(id: "resolver") { context in
        XCTFail("Unexpected error: \(context.error)")
      }],
      reducers: [sample03Reducer],
      onLog: { message in
        logs.append(message)
      }
    )
    let header = "Log Header"

    store.dispatch(.setHeader(header))

    let hasReducerLog = logs.contains { log in
      guard case let .reducer(reducerId, action, _, succeded) = log else {
        return false
      }
      guard case let .setHeader(registeredHeader) = action else {
        return false
      }
      return reducerId == "sample03Reducer" && registeredHeader == header && succeded
    }
    XCTAssertTrue(hasReducerLog, "Expected complete() to emit reducer log when onLog is enabled.")
  }
}
