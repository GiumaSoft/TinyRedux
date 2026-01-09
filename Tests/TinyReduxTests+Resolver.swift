//

import Testing
@testable import TinyRedux


extension TinyReduxTests {

  /// ResolverContext carries the `origin` property — the `id` of the middleware that threw or returned
  /// `.resolve`. This enables targeted error handling where different resolvers can specialize in recovering
  /// errors from specific middleware sources, routing recovery logic based on origin identity rather than
  /// relying solely on error type introspection, which would be fragile across refactorings.
  @Test
  func resolverReceivesOrigin() async {
    let state = TestState()
    var capturedOrigin: String?

    let middleware = AnyMiddleware<TestState, TestAction>(id: "throwing-middleware") { context in
      throw TestError.test
    }
    let resolver = AnyResolver<TestState, TestAction>(id: "resolver") { context in
      capturedOrigin = context.origin
      return .exit(.success(()))
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [resolver],
      reducers: []
    )

    let _ = await store.dispatchWithResult(.run)

    #expect(capturedOrigin == "throwing-middleware")
  }

  /// Returning `.next` from a resolver forwards the error and action to the next resolver in the fold chain.
  /// This test configures two resolvers where the first passes and the second completes, verifying that both
  /// execute in order. The chain propagation is essential for layered error recovery — each resolver inspects
  /// the error and either handles it or delegates to the next specialist in the pipeline.
  @Test
  func resolverChainForwardsErrorThroughNext() async {
    let state = TestState()
    var resolverCalls: [String] = []

    let middleware = AnyMiddleware<TestState, TestAction>(id: "throw-mw") { context in
      throw TestError.test
    }
    let resolverA = AnyResolver<TestState, TestAction>(id: "rA") { context in
      resolverCalls.append("rA")
      return .next
    }
    let resolverB = AnyResolver<TestState, TestAction>(id: "rB") { context in
      resolverCalls.append("rB")
      return .exit(.success(()))
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [resolverA, resolverB],
      reducers: []
    )

    let _ = await store.dispatchWithResult(.run)

    #expect(resolverCalls == ["rA", "rB"])
  }

  /// Resolvers can dispatch recovery actions via `context.dispatch` to trigger compensating state mutations.
  /// The dispatched action enters the AsyncStream and is processed in a subsequent loop iteration — not inline.
  /// This test throws from a middleware, dispatches `.inc` from the resolver, and verifies the reducer
  /// increments state, confirming the full recovery-via-redispatch flow works end-to-end across pipeline cycles.
  @Test
  func resolverCanDispatchRecoveryAction() async {
    let state = TestState()

    let middleware = AnyMiddleware<TestState, TestAction>(id: "throw-mw") { context in
      if context.action == .run {
        throw TestError.test
      }
      return .next
    }
    let resolver = AnyResolver<TestState, TestAction>(id: "recovery") { context in
      context.dispatch(0, .inc)
      return .exit(.success(()))
    }
    let reducer = AnyReducer<TestState, TestAction>(id: "inc") { context in
      if context.action == .inc {
        context.state.value += 1
      }
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [resolver],
      reducers: [reducer]
    )

    store.dispatch(.run)

    await Self.poll { state.value < 1 }

    #expect(state.value == 1)
  }

  /// ResolverContext exposes an `.args` computed property returning a (state, action, error, origin, dispatch)
  /// 5-tuple. This enables ergonomic destructuring at the call site via a single `let` binding, giving the
  /// resolver handler direct access to all contextual values — particularly useful when the handler needs
  /// multiple fields simultaneously for branching logic based on error type, origin, and current action.
  @Test
  func resolverContextArgsDestructure() async {
    let state = TestState()
    var capturedOrigin: String?

    let middleware = AnyMiddleware<TestState, TestAction>(id: "throw-mw") { context in
      throw TestError.test
    }
    let resolver = AnyResolver<TestState, TestAction>(id: "resolver") { context in
      let (_, _, _, origin, _) = context.args
      capturedOrigin = origin
      return .exit(.success(()))
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [resolver],
      reducers: []
    )

    let _ = await store.dispatchWithResult(.run)

    #expect(capturedOrigin == "throw-mw")
  }

  /// Returning `.exit(.success(()))` from a resolver signals the error has been fully handled and stops the
  /// chain. Subsequent resolvers in the array never execute. This is the standard success-path exit for error
  /// recovery — the resolver acknowledges the error, optionally dispatches compensating actions, and tells
  /// the pipeline there is nothing left to do, preventing unnecessary processing by downstream resolvers.
  @Test
  func resolverExitSuccess() async {
    let state = TestState()
    var resolverBCalled = false

    let middleware = AnyMiddleware<TestState, TestAction>(id: "throw-mw") { context in
      throw TestError.test
    }
    let resolverA = AnyResolver<TestState, TestAction>(id: "rA") { context in
      return .exit(.success(()))
    }
    let resolverB = AnyResolver<TestState, TestAction>(id: "rB") { context in
      resolverBCalled = true
      return .exit(.failure(context.error))
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [resolverA, resolverB],
      reducers: []
    )

    let _ = await store.dispatchWithResult(.run)

    #expect(resolverBCalled == false)
  }

  /// Returning `.exit(.failure(error))` terminates the resolver chain and marks the error as unrecoverable.
  /// No subsequent resolvers execute and the pipeline ends without any state mutation. Unlike `.exit(.success)`
  /// which indicates successful handling, `.exit(.failure)` signals that the error was recognized but
  /// intentionally discarded — useful for suppressing known transient errors or errors from deprecated
  /// middleware that should not trigger recovery.
  @Test
  func resolverExitFailure() async {
    let state = TestState()
    var resolverBCalled = false

    let middleware = AnyMiddleware<TestState, TestAction>(id: "throw-mw") { context in
      throw TestError.test
    }
    let resolverA = AnyResolver<TestState, TestAction>(id: "rA") { context in
      return .exit(.failure(context.error))
    }
    let resolverB = AnyResolver<TestState, TestAction>(id: "rB") { context in
      resolverBCalled = true
      return .exit(.success(()))
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [resolverA, resolverB],
      reducers: []
    )

    let _ = await store.dispatchWithResult(.run)

    #expect(resolverBCalled == false)
  }

  /// Returning `.reduce` short-circuits from the resolver chain directly into the reducer with the current
  /// action. The remaining resolvers are skipped and the reducer executes as if the middleware had returned
  /// `.next`. This enables a powerful recovery pattern: a resolver can decide the error is not fatal and
  /// allow the original action to proceed to state mutation, effectively "healing" the pipeline mid-flight.
  @Test
  func resolverReduce() async {
    let state = TestState()

    let middleware = AnyMiddleware<TestState, TestAction>(id: "throw-mw") { context in
      throw TestError.test
    }
    let resolver = AnyResolver<TestState, TestAction>(id: "reducer-resolver") { context in
      return .reduce
    }
    let reducer = AnyReducer<TestState, TestAction>(id: "r") { context in
      context.state.value += 1
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [resolver],
      reducers: [reducer]
    )

    let _ = await store.dispatchWithResult(.run)

    #expect(state.value == 1)
  }

  /// Returning `.reduceAs(newAction)` short-circuits from the resolver chain to the reducer with a substituted
  /// action, replacing the original action that triggered the error. This combines error recovery with action
  /// transformation — the resolver determines that while the original action failed, a fallback action should
  /// be applied to state instead, enabling graceful degradation without requiring a separate dispatch cycle.
  @Test
  func resolverReduceAs() async {
    let state = TestState()

    let middleware = AnyMiddleware<TestState, TestAction>(id: "throw-mw") { context in
      throw TestError.test
    }
    let resolver = AnyResolver<TestState, TestAction>(id: "reduce-as") { context in
      return .reduceAs(.inc)
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
      resolvers: [resolver],
      reducers: [reducer]
    )

    let _ = await store.dispatchWithResult(.run)

    #expect(state.value == 1)
  }

  /// Returning `.nextAs(error, action)` forwards a modified error and action pair to the next resolver in
  /// the chain. This enables resolver-level transformation where one resolver enriches or re-categorizes the
  /// error before passing it downstream, and simultaneously swaps the action to influence how subsequent
  /// resolvers or an eventual `.reduce` will handle the recovery — a composable error rewriting mechanism.
  @Test
  func resolverNextAs() async {
    let state = TestState()
    var resolverBAction: TestAction?

    let middleware = AnyMiddleware<TestState, TestAction>(id: "throw-mw") { context in
      throw TestError.test
    }
    let resolverA = AnyResolver<TestState, TestAction>(id: "rA") { context in
      return .nextAs(TestError.manual, .inc)
    }
    let resolverB = AnyResolver<TestState, TestAction>(id: "rB") { context in
      resolverBAction = context.action
      return .exit(.success(()))
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [resolverA, resolverB],
      reducers: []
    )

    let _ = await store.dispatchWithResult(.run)

    #expect(resolverBAction == .inc)
  }
}
