//

import XCTest
@testable import Example
@testable import TinyRedux

@MainActor
final class TinyReduxAdhocTests: XCTestCase {
  func testSample03ReducerUpdatesHeader() {
    let state = AppState()
    let store = Store.sharedInstance(
      override: true,
      initialState: state,
      middlewares: [],
      resolvers: [Resolver(id: "resolver") { context in
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
    var logs: [String] = []
    let store = Store.sharedInstance(
      override: true,
      initialState: state,
      middlewares: [],
      resolvers: [Resolver(id: "resolver") { context in
        XCTFail("Unexpected error: \(context.error)")
      }],
      reducers: [sample03Reducer],
      onLog: { message in
        logs.append(message)
      }
    )

    store.dispatch(.setHeader("Log Header"))

    let hasReducerLog = logs.contains { $0.contains("sample03Reducer reduce .setHeader") }
    XCTAssertTrue(hasReducerLog, "Expected complete() to emit reducer log when onLog is enabled.")
  }
}
