//

import Testing
@testable import TinyRedux


extension TinyReduxTests {

  /// Returning `.nextAs(newAction)` transforms the action before forwarding it to the next middleware in
  /// the fold chain. The original action is discarded and the modified action propagates through all remaining
  /// middleware and into the reducer. This is the primary mechanism for action normalization, mapping, or
  /// aliasing — allowing middleware to rewrite intent without dispatching a separate follow-up action.
  @Test
  func middlewareNextAs() async {
    let state = TestState()

    let middleware = AnyMiddleware<TestState, TestAction>(id: "transform") { context in
      if context.action == .run {
        return .nextAs(.inc)
      }
      return .next
    }
    let reducer = AnyReducer<TestState, TestAction>(id: "r") { context in
      if context.action == .inc {
        context.state.value += 1
      }
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [],
      reducers: [reducer]
    )

    let result = await store.dispatchAndDecode(.run)

    #expect(result.value == 1)
  }

  /// Returning `.exit(.success)` exits the middleware chain and short-circuits to the reducer chain.
  /// Remaining middlewares are skipped but reducers execute normally. This enables a middleware to signal
  /// that it has handled the action and no further middleware processing is needed, while still allowing
  /// the reducer to apply state mutations — e.g., a caching middleware that resolves data but still wants
  /// the reducer to store it.
  @Test
  func middlewareExitSuccess() async {
    let state = TestState()
    var reducerCalled = false

    let middleware = AnyMiddleware<TestState, TestAction>(id: "exit-ok") { context in
      return .exit(.success)
    }
    let reducer = AnyReducer<TestState, TestAction>(id: "r") { context in
      if context.action == .run {
        context.state.value += 1
      }
      reducerCalled = true
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [],
      reducers: [reducer]
    )

    let result = await store.dispatchAndDecode(.run)

    #expect(reducerCalled == true)
    #expect(result.value == 1)
  }

  /// Returning `.exit(.failure(error))` terminates the pipeline with an error signal. Neither the reducer
  /// nor the resolver chain executes — the error is not recoverable through the normal resolution path.
  /// This covers scenarios where the middleware detects a fatal condition (invalid token, corrupted payload)
  /// that should abort processing entirely rather than attempting any form of error recovery or state change.
  @Test
  func middlewareExitFailure() async {
    let state = TestState()
    var reducerCalled = false
    var resolverCalled = false

    let middleware = AnyMiddleware<TestState, TestAction>(id: "exit-fail") { context in
      return .exit(.failure(TestError.test))
    }
    let resolver = AnyResolver<TestState, TestAction>(id: "resolver") { context in
      resolverCalled = true
      return .exit(.success)
    }
    let reducer = AnyReducer<TestState, TestAction>(id: "r") { _ in
      reducerCalled = true
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [resolver],
      reducers: [reducer]
    )

    let _ = await store.dispatch(.run, snapshot: TestSnapshot.self)

    #expect(reducerCalled == false)
    #expect(resolverCalled == false)
  }
}
