//

import Synchronization
import Testing
@testable import TinyRedux


extension TinyReduxTests {

  /// The `onLog` callback receives a `Store.Log` entry for every pipeline component that executes. This test
  /// configures one middleware and one reducer, dispatches a single action, and verifies that exactly two log
  /// entries are emitted — one for the middleware and one for the reducer. This confirms the automatic timing
  /// and diagnostics system fires for each component without requiring any opt-in from the component itself.
  @Test
  func onLogCallbackReceivesMiddlewareLog() async {
    let state = TestState()
    let logEntries = Mutex<[Store<TestState, TestAction>.Log]>([])

    let middleware = AnyMiddleware<TestState, TestAction>(id: "logged-mw") { context in
      return .next
    }
    let reducer = AnyReducer<TestState, TestAction>(id: "logged-r") { _ in
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [],
      reducers: [reducer],
      onLog: { log in
        logEntries.withLock { $0.append(log) }
      }
    )

    let _ = await store.dispatchWithResult(.run)

    #expect(logEntries.withLock { $0.count } == 2)
  }

  /// When a middleware throws or returns `.resolve`, the error flows to the resolver chain, and the resolver's
  /// execution is also logged via `onLog`. This test verifies that a `.resolver` log entry is emitted when
  /// a resolver handles an error — confirming the diagnostics system covers the error recovery path in addition
  /// to the normal middleware-reducer flow, giving full pipeline observability for debugging and performance analysis.
  @Test
  func onLogCallbackReceivesResolverLog() async {
    let state = TestState()
    let resolverLogReceived = Mutex(false)

    let middleware = AnyMiddleware<TestState, TestAction>(id: "throw-mw") { context in
      throw TestError.test
    }
    let resolver = AnyResolver<TestState, TestAction>(id: "logged-resolver") { context in
      return .exit(.success)
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [resolver],
      reducers: [],
      onLog: { log in
        if case .resolver = log {
          resolverLogReceived.withLock { $0 = true }
        }
      }
    )

    let _ = await store.dispatchWithResult(.run)

    let received = resolverLogReceived.withLock { $0 }
    #expect(received)
  }
}
