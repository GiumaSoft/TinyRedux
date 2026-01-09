//

import Foundation
import Synchronization
import Testing
@testable import TinyRedux


extension TinyReduxTests {

  /// The `.task` closure must execute off MainActor to avoid blocking the UI thread during async side effects.
  /// This test dispatches a task, yields to allow scheduling, then checks `Thread.isMainThread` from inside
  /// the task body — confirming the framework's concurrency boundary pushes async work to a background executor.
  @Test
  func middlewareTaskRunsOffMainActor() async {
    let state = TestState()
    let isMain = Mutex<Bool?>(nil)

    let middleware = AnyMiddleware<TestState, TestAction>(id: "task-isolation") { context in
      return .task { _ in
        await Task.yield()
        isMain.withLock { $0 = Thread.isMainThread }
      }
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [],
      reducers: []
    )

    store.dispatch(.run)

    await Self.poll { isMain.withLock { $0 } == nil }

    #expect(isMain.withLock { $0 } == false)
  }

  /// Returning `.task` implies `.next` — the pipeline continues to the reducer immediately without waiting
  /// for the async task to complete. This fire-and-forget semantic means the reducer sees the state mutation
  /// synchronously while the task runs in the background, enabling non-blocking side effects like analytics
  /// or pre-fetching that should never delay the user-facing state update.
  @Test
  func middlewareTaskFireAndForget() async {
    let state = TestState()
    let taskRan = Mutex(false)

    let middleware = AnyMiddleware<TestState, TestAction>(id: "task-mw") { context in
      return .task { _ in
        taskRan.withLock { $0 = true }
      }
    }
    let reducer = AnyReducer<TestState, TestAction>(id: "r") { context in
      context.state.value += 1
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [],
      reducers: [reducer]
    )

    let _ = await store.dispatchWithResult(.run)

    // Reducer runs because .task implies .next
    #expect(state.value == 1)

    await Self.poll { !taskRan.withLock { $0 } }

    #expect(taskRan.withLock { $0 })
  }

  /// `.deferred` suspends the pipeline until the handler calls `resume`. This test passes `.next` to resume,
  /// which forwards the action to the remaining middleware chain and eventually to the reducer. The deferred
  /// pattern is essential for async operations (network calls, animations) where the pipeline must wait for
  /// an external result before deciding whether to proceed, transform, or reject the action.
  @Test
  func middlewareDeferred() async {
    let state = TestState()

    let middleware = AnyMiddleware<TestState, TestAction>(id: "deferred-mw") { context in
      return .deferred { _ in return .next }
    }
    let reducer = AnyReducer<TestState, TestAction>(id: "r") { context in
      context.state.value += 1
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

  /// Returning `.resolve(error)` from a deferred handler routes the error to the resolver chain,
  /// exactly as if the middleware had thrown or returned `.resolve`. This verifies that deferred middleware
  /// can perform async validation and, upon discovering a problem, hand it to the error recovery system
  /// rather than silently dropping the action or crashing with an unhandled exception.
  @Test
  func middlewareDeferredResolve() async {
    let state = TestState()
    var resolverCalled = false

    let middleware = AnyMiddleware<TestState, TestAction>(id: "deferred-resolve") { context in
      return .deferred { _ in return .resolve(TestError.test) }
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

    store.dispatch(.run)

    await Self.poll { !resolverCalled }

    #expect(resolverCalled)
  }

  /// Returning `.exit(.success)` from a deferred handler short-circuits to the reducer chain,
  /// consistent with the synchronous `.exit(.success)` path. The reducer runs and the deferred exit emits
  /// a log entry for the middleware, confirming the diagnostics system tracks deferred completions just as
  /// it tracks synchronous exits, so timing and flow analysis remain accurate for async middleware paths.
  @Test
  func middlewareDeferredExit() async {
    let state = TestState()
    var reducerCalled = false
    let logReceived = Mutex(false)

    let middleware = AnyMiddleware<TestState, TestAction>(id: "deferred-exit") { context in
      return .deferred { _ in return .exit(.success) }
    }
    let reducer = AnyReducer<TestState, TestAction>(id: "r") { context in
      reducerCalled = true
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [],
      reducers: [reducer],
      onLog: { log in
        if case .middleware("deferred-exit", _, _, _) = log {
          logReceived.withLock { $0 = true }
        }
      }
    )

    store.dispatch(.run)

    await Self.poll { !logReceived.withLock { $0 } }

    #expect(logReceived.withLock { $0 })
    #expect(reducerCalled == true)
  }

  /// When a deferred handler throws, the framework auto-catches the error and routes it to the resolver
  /// chain — identical to the `.task` error path. This eliminates the need for manual `do/catch` + `resume`
  /// inside deferred handlers: a bare `throw` is equivalent to returning `.resolve(error)`.
  @Test
  func middlewareDeferredThrowRoutesToResolver() async {
    let state = TestState()
    var resolverCalled = false

    let middleware = AnyMiddleware<TestState, TestAction>(id: "deferred-throw") { context in
      return .deferred { _ in throw TestError.test }
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

    store.dispatch(.run)

    await Self.poll { !resolverCalled }

    #expect(resolverCalled)
  }

  /// The deferred handler receives the store's read-only state, allowing it to base its async decision
  /// on the current state snapshot. This test sets state before dispatch and verifies the handler can read it.
  @Test
  func middlewareDeferredReadsState() async {
    let state = TestState()
    state.value = 42
    let readValue = Mutex<Int?>(nil)

    let middleware = AnyMiddleware<TestState, TestAction>(id: "deferred-state") { context in
      return .deferred { readOnly in
        let v = await readOnly.value
        readValue.withLock { $0 = v }
        return .next
      }
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [],
      reducers: []
    )

    store.dispatch(.run)

    await Self.poll { readValue.withLock { $0 } == nil }

    #expect(readValue.withLock { $0 } == 42)
  }
}
