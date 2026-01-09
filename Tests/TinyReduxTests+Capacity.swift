//

import Synchronization
import Testing
@testable import TinyRedux


extension TinyReduxTests {

  // MARK: - StoreOptions

  /// `StoreOptions` default `dispatcherCapacity` is `256` — matches the historical
  /// transport buffer size, kept as the recommended default after the transport
  /// switched to `.unbounded`.
  @Test
  func storeOptionsDefaultDispatcherCapacityIs256() {
    let options = StoreOptions()

    #expect(options.dispatcherCapacity == 256)
  }

  /// `StoreOptions` accepts custom positive values: callers are free to pick small
  /// capacities (e.g. for tests) or larger ones for high-throughput scenarios.
  @Test
  func storeOptionsAcceptsCustomCapacity() {
    let small = StoreOptions(dispatcherCapacity: 4)
    let large = StoreOptions(dispatcherCapacity: 4096)

    #expect(small.dispatcherCapacity == 4)
    #expect(large.dispatcherCapacity == 4096)
  }

#if !DEBUG
  /// Invalid capacities clamp to `1` outside debug assertion builds.
  @Test
  func storeOptionsClampsInvalidCapacityOutsideDebug() {
    let zero = StoreOptions(dispatcherCapacity: 0)
    let negative = StoreOptions(dispatcherCapacity: -4)

    #expect(zero.dispatcherCapacity == 1)
    #expect(negative.dispatcherCapacity == 1)
  }
#endif

  // MARK: - Dispatcher capacity accounting

  /// `pendingCount` increments on every accepted enqueue, including unlimited
  /// (`limit == 0`) enqueues — capacity guards the dispatcher even when no per-action
  /// limit is provided.
  @Test
  func pendingCountIncrementsForLimitZeroEnqueue() {
    let dispatcher = Store<TestState, TestAction>.Worker.Dispatcher(capacity: 256)

    _ = dispatcher.tryEnqueue(
      id: "x",
      limit: 0,
      (action: TestAction.inc, onSnapshot: nil)
    )
    _ = dispatcher.tryEnqueue(
      id: "x",
      limit: 0,
      (action: TestAction.inc, onSnapshot: nil)
    )

    #expect(dispatcher.pendingCount == 2)
  }

  /// `consume(id:)` decrements `pendingCount` and is safe even when `counts[id]`
  /// is missing (e.g. after `flush()` reset). Floors at zero — never goes negative.
  @Test
  func consumeDecrementsPendingCountAndSurvivesCountsReset() {
    let dispatcher = Store<TestState, TestAction>.Worker.Dispatcher(capacity: 256)

    _ = dispatcher.tryEnqueue(
      id: "x",
      limit: 0,
      (action: TestAction.inc, onSnapshot: nil)
    )
    _ = dispatcher.tryEnqueue(
      id: "x",
      limit: 0,
      (action: TestAction.inc, onSnapshot: nil)
    )

    dispatcher.flush()
    /// counts is now reset to [:], pendingCount stays at 2 until events are drained.
    dispatcher.consume(id: "x")
    dispatcher.consume(id: "x")
    /// extra consume is a no-op (floor at zero).
    dispatcher.consume(id: "x")

    #expect(dispatcher.pendingCount == 0)
  }

  /// When the dispatcher reaches `dispatcherCapacity`, further enqueues fail with
  /// `.bufferLimitReached` until pending events are consumed by the worker.
  @Test
  func tryEnqueueFailsWithBufferLimitWhenAtCapacity() {
    let dispatcher = Store<TestState, TestAction>.Worker.Dispatcher(capacity: 2)

    _ = dispatcher.tryEnqueue(id: "x", limit: 0, (action: TestAction.inc, onSnapshot: nil))
    _ = dispatcher.tryEnqueue(id: "x", limit: 0, (action: TestAction.inc, onSnapshot: nil))
    let third = dispatcher.tryEnqueue(
      id: "x",
      limit: 0,
      (action: TestAction.inc, onSnapshot: nil)
    )

    guard case .failure(.bufferLimitReached) = third else {
      Issue.record("expected .failure(.bufferLimitReached), got \(third)")

      return
    }
  }

  /// `tryEnqueue` reports `.maxDispatchableReached` when the per-action `limit`
  /// is exceeded — distinct outcome from `bufferLimitReached`.
  @Test
  func tryEnqueueFailsWithMaxDispatchableReached() {
    let dispatcher = Store<TestState, TestAction>.Worker.Dispatcher(capacity: 256)

    _ = dispatcher.tryEnqueue(id: "x", limit: 1, (action: TestAction.inc, onSnapshot: nil))
    let second = dispatcher.tryEnqueue(
      id: "x",
      limit: 1,
      (action: TestAction.inc, onSnapshot: nil)
    )

    guard case .failure(.maxDispatchableReached) = second else {
      Issue.record("expected .failure(.maxDispatchableReached), got \(second)")

      return
    }
  }

  /// `tryEnqueue` reports `.terminated` after the dispatcher stream is closed.
  @Test
  func tryEnqueueFailsWithTerminatedAfterFinish() {
    let dispatcher = Store<TestState, TestAction>.Worker.Dispatcher(capacity: 256)

    dispatcher.finish()
    let result = dispatcher.tryEnqueue(
      id: "x",
      limit: 0,
      (action: TestAction.inc, onSnapshot: nil)
    )

    guard case .failure(.terminated) = result else {
      Issue.record("expected .failure(.terminated), got \(result)")

      return
    }
  }

  // MARK: - Discard log

  /// Buffer-limit rejections produce a `.store(...)` discard log carrying the
  /// failure reason. Capacity is forced low via
  /// `StoreOptions` to make the buffer fill deterministically inside a single
  /// blocking middleware.
  @Test
  func bufferLimitRejectionEmitsStoreDiscardLog() async {
    let state = TestState()
    let logEntries = Mutex<[String]>([])
    let release = Mutex<Bool>(false)

    let middleware = AnyMiddleware<TestState, TestAction>(id: "blocker") { _ in
      .deferred { _ in
        while !release.withLock({ $0 }) {
          try? await Task.sleep(nanoseconds: 1_000_000)
        }

        return .next
      }
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [],
      reducers: [],
      options: StoreOptions(dispatcherCapacity: 1),
      onLog: { log in
        if case .store(let message) = log {
          logEntries.withLock { $0.append(message) }
        }
      }
    )

    /// First action occupies the only slot, parks inside the deferred handler.
    store.dispatch(.run)
    /// Second action must hit `bufferLimitReached`.
    let result = await store.dispatch(.inc, snapshot: TestSnapshot.self)

    #expect(result.isFailure)

    await Self.poll { logEntries.withLock { $0.isEmpty } }

    let messages = logEntries.withLock { $0 }
    #expect(messages.contains { $0.contains("buffer limit reached") })
    #expect(messages.contains { $0 == "Store discarded action due to buffer limit reached." })

    release.withLock { $0 = true }
  }

  /// Per-action limit rejections produce a discard log with the
  /// `maxDispatchableReached` reason.
  @Test
  func maxDispatchableRejectionEmitsStoreDiscardLog() async {
    let state = TestState()
    let logEntries = Mutex<[String]>([])
    let store = Store<TestState, TestAction>(
      initialState: state,
      middlewares: [],
      resolvers: [],
      reducers: [],
      onLog: { log in
        if case .store(let message) = log {
          logEntries.withLock { $0.append(message) }
        }
      }
    )

    store.dispatch(maxDispatchable: 1, .inc)
    store.dispatch(maxDispatchable: 1, .inc)

    await Self.poll { logEntries.withLock { $0 }.contains("Store discarded action due to max dispatchable reached.") == false }

    #expect(logEntries.withLock { $0 }.contains("Store discarded action due to max dispatchable reached."))
  }

  /// `staleGeneration` failures are silent — `flush()` invalidates ghost
  /// subscription dispatches without spamming the discard log.
  @Test
  func staleGenerationDoesNotEmitDiscardLog() async {
    let state = TestState()
    let logEntries = Mutex<[String]>([])

    let store = Store<TestState, TestAction>(
      initialState: state,
      middlewares: [],
      resolvers: [],
      reducers: [],
      options: StoreOptions(dispatcherCapacity: 8),
      onLog: { log in
        if case .store(let message) = log {
          logEntries.withLock { $0.append(message) }
        }
      }
    )

    store.flush()
    /// Force a stale-generation tryEnqueue directly on the dispatcher — bypasses
    /// the worker dispatch APIs to isolate the silent path.
    let result = store.worker.dispatcher.tryEnqueue(
      id: "x",
      limit: 0,
      generation: 0,
      (action: TestAction.inc, onSnapshot: nil)
    )

    guard case .failure(.staleGeneration) = result else {
      Issue.record("expected .failure(.staleGeneration), got \(result)")

      return
    }

    /// Give any spurious log Task time to surface; expect none.
    try? await Task.sleep(nanoseconds: 10_000_000)
    #expect(logEntries.withLock { $0 }.contains { $0.contains("stale generation") } == false)
  }

  /// Suspending the store and dispatching afterwards triggers a `.suspended`
  /// discard log — surfaces lifecycle misuse without going silent.
  @Test
  func suspendedRejectionEmitsDiscardLog() async {
    let state = TestState()
    let logEntries = Mutex<[String]>([])

    let store = Store<TestState, TestAction>(
      initialState: state,
      middlewares: [],
      resolvers: [],
      reducers: [],
      onLog: { log in
        if case .store(let message) = log {
          logEntries.withLock { $0.append(message) }
        }
      }
    )

    store.suspend()
    let result = await store.dispatch(.inc, snapshot: TestSnapshot.self)

    #expect(result.isFailure)

    await Self.poll { logEntries.withLock { $0 }.contains { $0.contains("dispatcher suspended") } == false }

    #expect(logEntries.withLock { $0 }.contains { $0.contains("dispatcher suspended") })
  }

  /// Dispatching after dispatcher termination emits a `.terminated` discard log.
  @Test
  func terminatedRejectionEmitsDiscardLog() async {
    let state = TestState()
    let logEntries = Mutex<[String]>([])
    let store = Store<TestState, TestAction>(
      initialState: state,
      middlewares: [],
      resolvers: [],
      reducers: [],
      onLog: { log in
        if case .store(let message) = log {
          logEntries.withLock { $0.append(message) }
        }
      }
    )

    store.worker.dispatcher.finish()
    let result = await store.dispatch(.inc, snapshot: TestSnapshot.self)

    #expect(result.isFailure)

    await Self.poll { logEntries.withLock { $0 }.contains("Store discarded action due to dispatcher terminated.") == false }

    #expect(logEntries.withLock { $0 }.contains("Store discarded action due to dispatcher terminated."))
  }

  /// Batch dispatch logs each rejected action independently — one discard log per
  /// rejection, no rollback of previously accepted actions.
  @Test
  func batchDispatchLogsEachRejectionIndependently() async {
    let state = TestState()
    let logEntries = Mutex<[String]>([])
    let release = Mutex<Bool>(false)

    let middleware = AnyMiddleware<TestState, TestAction>(id: "blocker") { _ in
      .deferred { _ in
        while !release.withLock({ $0 }) {
          try? await Task.sleep(nanoseconds: 1_000_000)
        }

        return .next
      }
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [],
      reducers: [],
      options: StoreOptions(dispatcherCapacity: 1),
      onLog: { log in
        if case .store(let message) = log {
          logEntries.withLock { $0.append(message) }
        }
      }
    )

    /// First action occupies the slot. Subsequent batch entries must each fail.
    store.dispatch(.run)
    store.dispatch(actions: [.inc, .inc, .inc])

    await Self.poll { logEntries.withLock { $0.count } < 3 }

    let bufferLogs = logEntries.withLock { $0 }.filter { $0.contains("buffer limit reached") }
    #expect(bufferLogs.count == 3)

    release.withLock { $0 = true }
  }

  // MARK: - Worker loop accounting

  /// `pendingCount` decrements after the worker has fully processed each event:
  /// once the suite drains, the dispatcher's pending count must be back to zero.
  @Test
  func pendingCountReturnsToZeroAfterPipelineDrain() async {
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
    #expect(store.worker.dispatcher.pendingCount == 0)
  }

  /// The current event keeps its capacity slot while synchronous middleware is running.
  @Test
  func pendingCountStaysOccupiedDuringSynchronousProcessing() async {
    let state = TestState()
    let observed = Mutex<[Int]>([])
    var store: Store<TestState, TestAction>!
    let middleware = AnyMiddleware<TestState, TestAction>(id: "observer") { _ in
      observed.withLock { $0.append(store.worker.dispatcher.pendingCount) }

      return .next
    }
    let reducer = AnyReducer<TestState, TestAction>(id: "inc") { context in
      if context.action == .inc {
        context.state.value += 1
      }

      return .next
    }
    store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [],
      reducers: [reducer],
      options: StoreOptions(dispatcherCapacity: 1)
    )

    let result = await store.dispatchAndDecode(.inc)

    #expect(result.value == 1)
    #expect(observed.withLock { $0 } == [1])
    #expect(store.worker.dispatcher.pendingCount == 0)
  }

  /// A subscription emits `.executed` only when its enqueue succeeds. With capacity
  /// `1`, the current action still occupies the only slot during subscription
  /// evaluation, so the subscription dispatch is rejected and no executed log is emitted.
  @Test
  func subscriptionExecutedLogOnlyEmitsOnEnqueueSuccess() async {
    let state = TestState()
    let executedCount = Mutex<Int>(0)
    let storeLogs = Mutex<[String]>([])
    let middleware = AnyMiddleware<TestState, TestAction>(id: "watcher") { context in
      if context.action == .run {
        context.subscribe(
          id: "capacity-blocked",
          when: { _ in true },
          then: { _ in .inc }
        )
      }

      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [],
      reducers: [],
      options: StoreOptions(dispatcherCapacity: 1),
      onLog: { log in
        switch log {
        ///
        case .subscription(.executed):
          executedCount.withLock { $0 += 1 }
        ///
        case .store(let message):
          storeLogs.withLock { $0.append(message) }
        ///
        default:
          break
        }
      }
    )

    let _ = await store.dispatch(.run, snapshot: TestSnapshot.self)

    #expect(executedCount.withLock { $0 } == 0)
    #expect(storeLogs.withLock { $0 }.contains("Store discarded action due to buffer limit reached."))
  }

  /// Re-entrant dispatch uses the same dispatcher capacity. With capacity `1`, the
  /// current action occupies the only slot, so the middleware's re-entrant action is rejected.
  @Test
  func reentrantDispatchRejectedWhenBufferIsFull() async {
    let state = TestState()
    let logEntries = Mutex<[String]>([])
    let middleware = AnyMiddleware<TestState, TestAction>(id: "redispatcher") { context in
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
      reducers: [reducer],
      options: StoreOptions(dispatcherCapacity: 1),
      onLog: { log in
        if case .store(let message) = log {
          logEntries.withLock { $0.append(message) }
        }
      }
    )

    let result = await store.dispatchAndDecode(.run)

    await Self.poll { logEntries.withLock { $0 }.contains("Store discarded action due to buffer limit reached.") == false }

    #expect(result.value == 0)
    #expect(state.value == 0)
    #expect(logEntries.withLock { $0 }.contains("Store discarded action due to buffer limit reached."))
  }
}
