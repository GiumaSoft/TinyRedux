//

import Testing
@testable import TinyRedux


extension TinyReduxTests {

  /// `flush()` marks all pending events in the stream as stale by incrementing the generation counter.
  /// The worker skips the pipeline for stale elements (completion-only). This test dispatches 5 `.inc`
  /// actions, flushes, then dispatches one more via `dispatchWithResult`. Only the post-flush action
  /// should reach the reducer, producing a value of 1.
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

    let result = await store.dispatchWithResult(.inc)

    #expect(result.value == 1)
  }

  /// When `dispatchWithResult` has a pending continuation and `flush()` invalidates the event, the
  /// continuation must still resume with the current state (completion-only path). This test dispatches
  /// actions with completions, flushes, then verifies `dispatchWithResult` still returns without hanging.
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

    store.dispatch(.inc, completion: { _ in })
    store.dispatch(.inc, completion: { _ in })
    store.dispatch(.inc, completion: { _ in })
    store.flush()

    let result = await store.dispatchWithResult(.inc)

    #expect(result.value >= 43)
  }
}
