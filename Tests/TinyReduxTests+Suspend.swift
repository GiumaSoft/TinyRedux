//

import Testing
@testable import TinyRedux


extension TinyReduxTests {

  /// After `suspend()`, new dispatches are rejected. `dispatch(_:snapshot:)` returns
  /// `.failure(EnqueueFailure.suspended)` and the pipeline never runs.
  @Test
  func suspendDropsNewDispatches() async {
    let state = TestState()
    let reducer = AnyReducer<TestState, TestAction>(id: "inc") { context in
      context.state.value += 1
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [],
      resolvers: [],
      reducers: [reducer]
    )

    store.suspend()

    let result = await store.dispatch(.inc, snapshot: TestSnapshot.self)

    #expect(result.isFailure)
    #expect(state.value == 0)
  }

  /// After `resume()`, dispatches are accepted again and the pipeline processes normally.
  @Test
  func resumeRestoresProcessing() async {
    let state = TestState()
    let reducer = AnyReducer<TestState, TestAction>(id: "inc") { context in
      context.state.value += 1
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [],
      resolvers: [],
      reducers: [reducer]
    )

    store.suspend()
    store.resume()

    let result = await store.dispatchAndDecode(.inc)

    #expect(result.value == 1)
  }

  /// `suspend()` flushes pending actions already in the stream buffer. Actions dispatched before
  /// `suspend()` are marked stale and skipped by the worker.
  @Test
  func suspendFlushesExistingPending() async {
    let state = TestState()
    let reducer = AnyReducer<TestState, TestAction>(id: "inc") { context in
      context.state.value += 1
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [],
      resolvers: [],
      reducers: [reducer]
    )

    for _ in 0..<5 { store.dispatch(.inc) }
    store.suspend()
    store.resume()

    let result = await store.dispatchAndDecode(.inc)

    #expect(result.value == 1)
  }
}
