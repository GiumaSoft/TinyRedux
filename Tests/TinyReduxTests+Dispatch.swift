//

import Synchronization
import Testing
@testable import TinyRedux


extension TinyReduxTests {

  /// `dispatch(_:snapshot:)` is the async/await entry point that suspends until the full pipeline
  /// completes and returns a `Result<Data, Error>` with an encoded snapshot. This test verifies
  /// the round-trip: dispatch an action, let the reducer mutate state, decode the snapshot and
  /// confirm it reflects the updated value.
  @Test
  func dispatchSnapshotReturnsUpdatedState() async {
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

    let result = await store.dispatchAndDecode(.inc)

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

  /// When `dispatch(_:snapshot:)` is called and the action is rejected by the dispatcher
  /// (buffer full), the result is `.failure(EnqueueFailure.bufferLimitReached)`.
  @Test
  func dispatchSnapshotRejectedReturnsFailure() async {
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
      reducers: [reducer],
      options: StoreOptions(dispatcherCapacity: 1)
    )

    store.dispatch(.inc)
    let result = await store.dispatch(.inc, snapshot: TestSnapshot.self)

    #expect(result.isFailure)
  }

  /// `dispatch(_:snapshot:)` must return state **after** the deferred resume completes the pipeline,
  /// not before. The completion is threaded to the terminal point (reduce), so the continuation
  /// resumes only after the reducer runs.
  @Test
  func dispatchSnapshotAfterDeferredReturnsPostReduceState() async {
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

    let result = await store.dispatchAndDecode(.inc)

    #expect(result.value == 1)
  }

  /// A `.deferred` middleware suspends its pipeline, allowing subsequently dispatched actions to overtake it.
  /// This test dispatches `.run` (deferred with a 30ms delay) then `.inc` (synchronous). Because `.inc` enters
  /// the stream after `.run` but completes while `.run` is suspended, the reducer log records "inc" before "run".
  @Test
  func deferredNextCanInterleaveReducerCompletionOrder() async {
    let state = TestState()

    let middleware = AnyMiddleware<TestState, TestAction>(id: "deferred-next") { context in
      switch context.action {
      ///
      case .run:

        return .deferred { _ in
          try? await Task.sleep(nanoseconds: 30_000_000)

          return .next
        }
      ///
      case .inc:

        return .next
      }
    }
    let reducer = AnyReducer<TestState, TestAction>(id: "record-order") { context in
      let (state, action) = context.args
      switch action {
      ///
      case .run: state.log.append("run")
      ///
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


extension Result {
  var isFailure: Bool {
    if case .failure = self { return true }

    return false
  }
}
