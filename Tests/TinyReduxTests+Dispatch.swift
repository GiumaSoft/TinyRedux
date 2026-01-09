//

import Synchronization
import Testing
@testable import TinyRedux


extension TinyReduxTests {

  /// `dispatchWithResult` is the async/await entry point that suspends until the full pipeline completes and
  /// returns the resulting `State.ReadOnly` projection. This test verifies the round-trip: dispatch an action,
  /// let the reducer mutate state, and confirm the returned read-only snapshot reflects the updated value —
  /// the fundamental contract that makes `dispatchWithResult` usable for sequential, testable dispatch flows.
  @Test
  func dispatchWithResultReturnsUpdatedState() async {
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

    let result = await store.dispatchWithResult(.inc)

    #expect(result.value == 1)
  }

  /// The `maxDispatchable` parameter implements rate limiting via the Dispatcher's Mutex-based counter. When
  /// the same action is dispatched multiple times and the limit is reached, subsequent enqueues are silently
  /// dropped. This test fires three `.inc` dispatches with limit 1 and confirms only one reaches the reducer,
  /// verifying the Dispatcher rejects excess buffered duplicates before they enter the AsyncStream.
  @Test
  func maxDispatchableDropsDuplicateBufferedActions() async {
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

    store.dispatch(maxDispatchable: 1, .inc)
    store.dispatch(maxDispatchable: 1, .inc)
    store.dispatch(maxDispatchable: 1, .inc)

    await Self.poll { state.value < 1 }

    #expect(state.value == 1)
  }

  /// When `dispatchWithResult` is called with a `maxDispatchable` limit and the action is throttled (rejected
  /// by the Dispatcher), it must still return a valid `State.ReadOnly` snapshot — the current state at the
  /// time of rejection. This test pre-sets state to 42, saturates the limit, then calls `dispatchWithResult`
  /// and verifies the returned value is at least 42, confirming throttled dispatches degrade gracefully.
  @Test
  func dispatchWithResultThrottledReturnsCurrentState() async {
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

    store.dispatch(maxDispatchable: 1, .inc)
    let result = await store.dispatchWithResult(maxDispatchable: 1, .inc)

    #expect(result.value >= 42)
  }

  /// `dispatchWithResult` must return state **after** the deferred resume completes the pipeline, not before.
  /// Without completion threading, the for-await loop calls completion immediately after `process()` returns,
  /// but `.deferred` returns before the resume fires — so the caller sees stale pre-reduce state. With
  /// completion threaded to the terminal point (reduce), the continuation resumes only after the reducer runs.
  @Test
  func dispatchWithResultAfterDeferredReturnsPostReduceState() async {
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

    let result = await store.dispatchWithResult(.inc)

    #expect(result.value == 1)
  }

  /// `dispatch(_:completion:)` must deliver state **after** the deferred resume completes the pipeline.
  /// This validates the same completion-threading fix for the callback-based dispatch variant: the completion
  /// closure fires only after the reducer runs, even when a `.deferred` middleware suspends the pipeline.
  @Test
  func dispatchCompletionAfterDeferredReceivesPostReduceState() async {
    let state = TestState()
    let reducerValue = Mutex(0)
    let completionSawReducer = Mutex<Bool?>(nil)

    let middleware = AnyMiddleware<TestState, TestAction>(id: "deferred-mw") { context in
      return .deferred { _ in return .next }
    }
    let reducer = AnyReducer<TestState, TestAction>(id: "r") { context in
      context.state.value += 1
      reducerValue.withLock { $0 = 1 }
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [],
      reducers: [reducer]
    )

    store.dispatch(.inc) { _ in
      completionSawReducer.withLock { $0 = reducerValue.withLock { $0 } == 1 }
    }

    await Self.poll { completionSawReducer.withLock { $0 } == nil }

    #expect(completionSawReducer.withLock { $0 } == true)
  }

  /// A `.deferred` middleware suspends its pipeline, allowing subsequently dispatched actions to overtake it.
  /// This test dispatches `.run` (deferred with a 30ms delay) then `.inc` (synchronous). Because `.inc` enters
  /// the stream after `.run` but completes while `.run` is suspended, the reducer log records "inc" before "run".
  /// This verifies the FIFO-per-completion ordering model: deferred actions yield their pipeline slot and resume
  /// later, enabling natural interleaving of fast and slow operations without head-of-line blocking.
  @Test
  func deferredNextCanInterleaveReducerCompletionOrder() async {
    let state = TestState()

    let middleware = AnyMiddleware<TestState, TestAction>(id: "deferred-next") { context in
      switch context.action {
      case .run:
        return .deferred { _ in
          try? await Task.sleep(nanoseconds: 30_000_000)
          return .next
        }
      case .inc:
        return .next
      }
    }
    let reducer = AnyReducer<TestState, TestAction>(id: "record-order") { context in
      let (state, action) = context.args
      switch action {
      case .run: state.log.append("run")
      case .inc: state.log.append("inc")
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
    store.dispatch(.inc)

    await Self.poll { state.log.count < 2 }

    #expect(state.log == ["inc", "run"])
  }
}
