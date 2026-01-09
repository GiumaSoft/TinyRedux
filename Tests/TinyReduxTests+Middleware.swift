//

import Testing
@testable import TinyRedux


extension TinyReduxTests {

  /// The fold-based middleware chain must preserve the user-supplied array order so that the first middleware
  /// in the array runs first, despite internal reversal at init. This is the core ordering contract: users
  /// reason about middleware execution left-to-right, and the fold must honor that mental model exactly.
  @Test
  func middlewareOrderIsPreserved() async {
    let state = TestState()
    var calls: [String] = []

    let m1 = AnyMiddleware<TestState, TestAction>(id: "m1") { context in
      calls.append("m1")
      return .next
    }
    let m2 = AnyMiddleware<TestState, TestAction>(id: "m2") { context in
      calls.append("m2")
      return .next
    }
    let reducer = AnyReducer<TestState, TestAction>(id: "r") { _ in
      calls.append("reducer")
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [m1, m2],
      resolvers: [],
      reducers: [reducer]
    )

    let _ = await store.dispatchWithResult(.run)

    #expect(calls == ["m1", "m2", "reducer"])
  }

  /// Returning `.exit(.failure)` from a middleware terminates the entire pipeline early — neither the
  /// reducer nor the resolver chain executes. This is the primary mechanism for blocking actions before
  /// they reach state mutation, used for guards, authentication checks, or any middleware that decides the
  /// action should be rejected outright.
  @Test
  func middlewareCanBlockPipeline() async {
    let state = TestState()
    var reducerCalled = false

    let middleware = AnyMiddleware<TestState, TestAction>(id: "blocker") { context in
      return .exit(.failure(TestError.test))
    }
    let reducer = AnyReducer<TestState, TestAction>(id: "r") { _ in
      reducerCalled = true
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [],
      reducers: [reducer]
    )

    let _ = await store.dispatchWithResult(.run)

    #expect(reducerCalled == false)
  }

  /// Middleware can enqueue a new action via `context.dispatch` while processing the current one. The new action
  /// enters the AsyncStream and is processed in a subsequent loop iteration — never inline. This verifies the
  /// decoupled dispatch model where side effects trigger follow-up actions without blocking the current pipeline.
  @Test
  func middlewareCanRedispatch() async {
    let state = TestState()

    let middleware = AnyMiddleware<TestState, TestAction>(id: "redispatch") { context in
      if context.action == .run {
        context.dispatch(0, .inc)
      }
      return .next
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
      resolvers: [],
      reducers: [reducer]
    )

    store.dispatch(.run)

    await Self.poll { state.value < 1 }

    #expect(state.value == 1)
  }

  /// MiddlewareContext exposes an `.args` computed property returning a (state, dispatch, action) 3-tuple.
  /// This enables ergonomic destructuring at the call site, letting middleware handlers bind all context
  /// values to named local variables in a single `let` statement instead of accessing properties individually.
  @Test
  func middlewareContextArgsDestructure() async {
    let state = TestState()
    var capturedAction: TestAction?

    let middleware = AnyMiddleware<TestState, TestAction>(id: "m") { context in
      let (_, _, action) = context.args
      capturedAction = action
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [],
      reducers: []
    )

    let _ = await store.dispatchWithResult(.run)

    #expect(capturedAction == .run)
  }

  /// Returning `.resolve(error)` from a middleware explicitly routes to the resolver chain without throwing
  /// an exception. This is the intentional error-injection path — the middleware decides an error condition
  /// exists and hands it to resolvers for recovery, bypassing the reducer entirely just like a thrown error would.
  @Test
  func middlewareResolveRoutesToResolverChain() async {
    let state = TestState()
    var resolverCalled = false

    let middleware = AnyMiddleware<TestState, TestAction>(id: "resolve-mw") { context in
      return .resolve(TestError.manual)
    }
    let resolver = AnyResolver<TestState, TestAction>(id: "resolver") { context in
      resolverCalled = true
      return .exit(.success)
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [resolver],
      reducers: []
    )

    let _ = await store.dispatchWithResult(.run)

    #expect(resolverCalled)
  }

  /// A coordinator captured by closure at file scope persists across dispatch cycles, enabling stateful
  /// side effects like counters, caches, or network session managers. The coordinator lives as a private
  /// let at file scope and is captured directly by the AnyMiddleware closure, decoupling state ownership
  /// from the middleware lifecycle while keeping the handler pure and testable.
  @Test
  func coordinatorCapturedByMiddlewarePersistsAcrossDispatches() async {
    let state = TestState()

    final class Coordinator: @unchecked Sendable {
      var count = 0
    }

    let coordinator = Coordinator()
    let middleware = AnyMiddleware<TestState, TestAction>(id: "stated") { context in
      coordinator.count += 1
      return .next
    }

    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [],
      reducers: []
    )

    store.dispatch(.run)
    store.dispatch(.inc)

    await Self.poll { coordinator.count < 2 }

    #expect(coordinator.count == 2)
  }
}
