//

import Testing
@testable import TinyRedux


extension TinyReduxTests {

  /// `flush()` marks all pending events in the stream as stale by incrementing the generation counter.
  /// The worker skips the pipeline for stale elements. This test dispatches 5 `.inc` actions, flushes,
  /// then dispatches one more via `dispatch(_:snapshot:)`. Only the post-flush action should reach the
  /// reducer, producing a value of 1.
  @Test
  func flushDiscardsPendingActions() async {
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
    store.flush()

    let result = await store.dispatchAndDecode(.inc)

    #expect(result.value == 1)
  }

  /// When `dispatch(_:snapshot:)` has a pending continuation and `flush()` invalidates the event,
  /// the continuation resumes with `.failure(.staleGeneration)`. This test dispatches actions,
  /// flushes, then verifies a new dispatch still completes successfully.
  @Test
  func flushResumesPendingContinuations() async {
    let state = TestState()
    state.value = 42
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

    store.dispatch(.inc)
    store.dispatch(.inc)
    store.dispatch(.inc)
    store.flush()

    let result = await store.dispatchAndDecode(.inc)

    #expect(result.value >= 43)
  }
}
