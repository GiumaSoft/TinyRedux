//

import Foundation
import Synchronization
import Testing
@testable import TinyRedux


extension TinyReduxTests {

  // MARK: - Return value

  /// `subscribe` returns the subscription id so callers can later `unsubscribe`.
  @Test
  func subscribeReturnsIdForCancellation() async {
    let state = TestState()
    let capturedId = Mutex<String?>(nil)

    let middleware = AnyMiddleware<TestState, TestAction>(id: "m") { context in
      if context.action == .run {
        let id = context.subscribe(
          when: { _ in false },
          then: { _ in .inc }
        )
        capturedId.withLock { $0 = id }
      }
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [],
      reducers: []
    )

    let _ = await store.dispatch(.run, snapshot: TestSnapshot.self)

    let id = capturedId.withLock { $0 }
    #expect(id != nil)
    #expect(UUID(uuidString: id ?? "") != nil)
  }

  /// `subscribe(id: "x", ...)` returns `"x"` unchanged.
  @Test
  func subscribeWithProvidedIdReturnsSameId() async {
    let state = TestState()
    let capturedId = Mutex<String?>(nil)

    let middleware = AnyMiddleware<TestState, TestAction>(id: "m") { context in
      if context.action == .run {
        let id = context.subscribe(
          id: "watcher-42",
          when: { _ in false },
          then: { _ in .inc }
        )
        capturedId.withLock { $0 = id }
      }
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [],
      reducers: []
    )

    let _ = await store.dispatch(.run, snapshot: TestSnapshot.self)

    #expect(capturedId.withLock { $0 } == "watcher-42")
  }

  /// The default `id` is a valid UUID string.
  @Test
  func subscribeWithDefaultIdReturnsUUIDString() async {
    let state = TestState()
    let capturedId = Mutex<String?>(nil)

    let middleware = AnyMiddleware<TestState, TestAction>(id: "m") { context in
      if context.action == .run {
        let id = context.subscribe(
          when: { _ in false },
          then: { _ in .inc }
        )
        capturedId.withLock { $0 = id }
      }
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [],
      reducers: []
    )

    let _ = await store.dispatch(.run, snapshot: TestSnapshot.self)

    let id = capturedId.withLock { $0 } ?? ""
    #expect(UUID(uuidString: id) != nil)
  }

  // MARK: - Firing

  /// A subscription fires on the post-reducer evaluation of a later action that makes `when` true.
  @Test
  func subscribeFiresWhenConditionBecomesTrue() async {
    let state = TestState()

    let middleware = AnyMiddleware<TestState, TestAction>(id: "watcher") { context in
      if context.action == .run {
        context.subscribe(
          when: { $0.value >= 1 },
          then: { _ in .inc }
        )
      }
      return .next
    }
    let reducer = AnyReducer<TestState, TestAction>(id: "inc") { ctx in
      if ctx.action == .inc {
        ctx.state.value += 1
      }
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [],
      reducers: [reducer]
    )

    let _ = await store.dispatch(.run, snapshot: TestSnapshot.self)
    let _ = await store.dispatch(.inc, snapshot: TestSnapshot.self)

    await Self.poll { state.value < 2 }

    #expect(state.value == 2)
  }

  /// If `when` is already true at the post-reducer evaluation of the registering action,
  /// the subscription fires in the same turn.
  @Test
  func subscribeFiresImmediatelyIfAlreadyTrueSameTurn() async {
    let state = TestState()
    state.value = 10

    let middleware = AnyMiddleware<TestState, TestAction>(id: "watcher") { context in
      if context.action == .run {
        context.subscribe(
          when: { $0.value >= 10 },
          then: { _ in .inc }
        )
      }
      return .next
    }
    let reducer = AnyReducer<TestState, TestAction>(id: "inc") { ctx in
      if ctx.action == .inc {
        ctx.state.value += 1
      }
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [],
      reducers: [reducer]
    )

    let _ = await store.dispatch(.run, snapshot: TestSnapshot.self)

    await Self.poll { state.value < 11 }

    #expect(state.value == 11)
  }

  /// A subscription is removed from the registry after firing (one-shot).
  @Test
  func subscribeIsOneShot() async {
    let state = TestState()

    let middleware = AnyMiddleware<TestState, TestAction>(id: "watcher") { context in
      if context.action == .run {
        context.subscribe(
          when: { $0.value >= 1 },
          then: { _ in .inc }
        )
      }
      return .next
    }
    let reducer = AnyReducer<TestState, TestAction>(id: "inc") { ctx in
      if ctx.action == .inc {
        ctx.state.value += 1
      }
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [],
      reducers: [reducer]
    )

    let _ = await store.dispatch(.run, snapshot: TestSnapshot.self)
    let _ = await store.dispatch(.inc, snapshot: TestSnapshot.self)
    await Self.poll { state.value < 2 }
    let _ = await store.dispatch(.inc, snapshot: TestSnapshot.self)

    await Self.poll(timeout: 100) { false }

    /// Expected: .run registers, .inc fires (value 1 → 2), subscription removed.
    /// Second .inc reaches reducer only (value 2 → 3). No re-fire.
    #expect(state.value == 3)
  }

  /// The `then` closure receives the post-reducer read-only state, not the state at registration time.
  @Test
  func thenBuilderReceivesFreshState() async {
    let state = TestState()
    let observedValueAtThen = Mutex<Int>(-1)

    let middleware = AnyMiddleware<TestState, TestAction>(id: "watcher") { context in
      if context.action == .run {
        context.subscribe(
          when: { $0.value >= 1 },
          then: { readOnly in
            observedValueAtThen.withLock { $0 = readOnly.value }

            return .inc
          }
        )
      }
      return .next
    }
    let reducer = AnyReducer<TestState, TestAction>(id: "inc") { ctx in
      if ctx.action == .inc {
        ctx.state.value += 1
      }
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [],
      reducers: [reducer]
    )

    let _ = await store.dispatch(.run, snapshot: TestSnapshot.self)
    let _ = await store.dispatch(.inc, snapshot: TestSnapshot.self)
    await Self.poll { observedValueAtThen.withLock { $0 } == -1 }

    /// `then` fires when value becomes 1 (first .inc), so it must see value == 1.
    #expect(observedValueAtThen.withLock { $0 } == 1)
  }

  // MARK: - FIFO

  /// Multiple subscriptions matching in the same post-reducer evaluation fire in registration order.
  @Test
  func multipleSubscriptionsFIFO() async {
    let state = TestState()

    let middleware = AnyMiddleware<TestState, TestAction>(id: "watcher") { context in
      if context.action == .run {
        context.subscribe(id: "a", when: { $0.value >= 1 }, then: { readOnly in
          state.log.append("a:\(readOnly.value)")

          return .inc
        })
        context.subscribe(id: "b", when: { $0.value >= 1 }, then: { readOnly in
          state.log.append("b:\(readOnly.value)")

          return .inc
        })
        context.subscribe(id: "c", when: { $0.value >= 1 }, then: { readOnly in
          state.log.append("c:\(readOnly.value)")

          return .inc
        })
      }
      return .next
    }
    let reducer = AnyReducer<TestState, TestAction>(id: "inc") { ctx in
      if ctx.action == .inc {
        ctx.state.value += 1
      }
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [],
      reducers: [reducer]
    )

    let _ = await store.dispatch(.run, snapshot: TestSnapshot.self)
    let _ = await store.dispatch(.inc, snapshot: TestSnapshot.self)
    await Self.poll { state.log.count < 3 }

    #expect(state.log == ["a:1", "b:1", "c:1"])
  }

  // MARK: - Dedupe replace

  /// Two subscriptions with the same id: the second replaces the first.
  @Test
  func subscribeWithDuplicateIdReplacesEntry() async {
    let state = TestState()

    let middleware = AnyMiddleware<TestState, TestAction>(id: "watcher") { context in
      if context.action == .run {
        context.subscribe(id: "x", when: { _ in true }, then: { _ in
          state.log.append("first")

          return .inc
        })
        context.subscribe(id: "x", when: { _ in true }, then: { _ in
          state.log.append("second")

          return .inc
        })
      }
      return .next
    }
    let reducer = AnyReducer<TestState, TestAction>(id: "inc") { ctx in
      if ctx.action == .inc {
        ctx.state.value += 1
      }
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [],
      reducers: [reducer]
    )

    let _ = await store.dispatch(.run, snapshot: TestSnapshot.self)
    await Self.poll { state.log.isEmpty }

    /// Only "second" must fire: the first was replaced by the second before evaluation.
    #expect(state.log == ["second"])
  }

  // MARK: - Unsubscribe

  /// `unsubscribe(id:)` removes the subscription immediately; it does not fire in subsequent evaluations.
  @Test
  func unsubscribeRemovesImmediately() async {
    let state = TestState()
    let firedCount = Mutex<Int>(0)

    let middleware = AnyMiddleware<TestState, TestAction>(id: "watcher") { context in
      switch context.action {
      case .run:
        context.subscribe(id: "cancelMe", when: { _ in true }, then: { _ in
          firedCount.withLock { $0 += 1 }

          return .inc
        })
        context.unsubscribe(id: "cancelMe")
      default:
        break
      }
      return .next
    }
    let reducer = AnyReducer<TestState, TestAction>(id: "inc") { ctx in
      if ctx.action == .inc {
        ctx.state.value += 1
      }
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [],
      reducers: [reducer]
    )

    let _ = await store.dispatch(.run, snapshot: TestSnapshot.self)
    await Self.poll(timeout: 100) { false }

    #expect(firedCount.withLock { $0 } == 0)
  }

  /// `unsubscribe(id:)` with a non-existent id is a silent no-op.
  @Test
  func unsubscribeNonExistentIsSilentNoOp() async {
    let state = TestState()
    let unsubscribedLogged = Mutex<Bool>(false)

    let middleware = AnyMiddleware<TestState, TestAction>(id: "watcher") { context in
      if context.action == .run {
        context.unsubscribe(id: "never-registered")
      }
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [],
      reducers: []
    ) { log in
      if case .subscription(.unsubscribed) = log {
        unsubscribedLogged.withLock { $0 = true }
      }
    }

    let _ = await store.dispatch(.run, snapshot: TestSnapshot.self)

    #expect(unsubscribedLogged.withLock { $0 } == false)
  }

  // MARK: - Flush invalidation via generation

  /// `store.flush()` invalidates pending subscriptions via generation bump.
  /// Subscriptions registered before the flush are removed silently; no `.executed` is emitted.
  @Test
  func flushInvalidatesPendingSubscriptionsViaGeneration() async {
    let state = TestState()
    let firedCount = Mutex<Int>(0)
    let executedLogCount = Mutex<Int>(0)

    let middleware = AnyMiddleware<TestState, TestAction>(id: "watcher") { context in
      if context.action == .run {
        context.subscribe(when: { $0.value >= 1 }, then: { _ in
          firedCount.withLock { $0 += 1 }

          return .inc
        })
      }
      return .next
    }
    let reducer = AnyReducer<TestState, TestAction>(id: "inc") { ctx in
      if ctx.action == .inc {
        ctx.state.value += 1
      }
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [],
      reducers: [reducer]
    ) { log in
      if case .subscription(.executed) = log {
        executedLogCount.withLock { $0 += 1 }
      }
    }

    let _ = await store.dispatch(.run, snapshot: TestSnapshot.self)
    store.flush()
    let _ = await store.dispatch(.inc, snapshot: TestSnapshot.self)
    await Self.poll(timeout: 100) { false }

    #expect(firedCount.withLock { $0 } == 0)
    #expect(executedLogCount.withLock { $0 } == 0)
  }

  // MARK: - Log correlation

  /// `.executed` log contains the dispatched action as 5th parameter.
  @Test
  func executedLogContainsDispatchedAction() async {
    let state = TestState()
    let capturedDispatched = Mutex<TestAction?>(nil)

    let middleware = AnyMiddleware<TestState, TestAction>(id: "watcher") { context in
      if context.action == .run {
        context.subscribe(when: { $0.value >= 1 }, then: { _ in .inc })
      }
      return .next
    }
    let reducer = AnyReducer<TestState, TestAction>(id: "inc") { ctx in
      if ctx.action == .inc {
        ctx.state.value += 1
      }
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [],
      reducers: [reducer]
    ) { log in
      if case .subscription(.executed(_, _, _, _, let dispatched)) = log {
        capturedDispatched.withLock { $0 = dispatched }
      }
    }

    let _ = await store.dispatch(.run, snapshot: TestSnapshot.self)
    let _ = await store.dispatch(.inc, snapshot: TestSnapshot.self)
    await Self.poll { capturedDispatched.withLock { $0 } == nil }

    #expect(capturedDispatched.withLock { $0 } == .inc)
  }

  /// `.subscribed` and `.executed` of the same subscription share the same `subId`.
  @Test
  func subscribedAndExecutedShareSubIdForCorrelation() async {
    let state = TestState()
    let subscribedSubId = Mutex<String?>(nil)
    let executedSubId = Mutex<String?>(nil)

    let middleware = AnyMiddleware<TestState, TestAction>(id: "watcher") { context in
      if context.action == .run {
        context.subscribe(
          id: "correlate-me",
          when: { $0.value >= 1 },
          then: { _ in .inc }
        )
      }
      return .next
    }
    let reducer = AnyReducer<TestState, TestAction>(id: "inc") { ctx in
      if ctx.action == .inc {
        ctx.state.value += 1
      }
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [],
      reducers: [reducer]
    ) { log in
      if case .subscription(.subscribed(_, let subId, _, _)) = log {
        subscribedSubId.withLock { $0 = subId }
      }
      if case .subscription(.executed(_, let subId, _, _, _)) = log {
        executedSubId.withLock { $0 = subId }
      }
    }

    let _ = await store.dispatch(.run, snapshot: TestSnapshot.self)
    let _ = await store.dispatch(.inc, snapshot: TestSnapshot.self)
    await Self.poll { executedSubId.withLock { $0 } == nil }

    #expect(subscribedSubId.withLock { $0 } == "correlate-me")
    #expect(executedSubId.withLock { $0 } == "correlate-me")
  }

  /// `unsubscribe(id:)` of an existing subscription emits a `.unsubscribed` log event
  /// with the canceller's middleware id and the sub id.
  @Test
  func unsubscribeEmitsUnsubscribedLog() async {
    let state = TestState()
    let unsubscribedCanceller = Mutex<String?>(nil)
    let unsubscribedSubId = Mutex<String?>(nil)

    let middleware = AnyMiddleware<TestState, TestAction>(id: "canceller") { context in
      if context.action == .run {
        context.subscribe(id: "target", when: { _ in false }, then: { _ in .inc })
        context.unsubscribe(id: "target")
      }
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [middleware],
      resolvers: [],
      reducers: []
    ) { log in
      if case .subscription(.unsubscribed(let canceller, let subId, _)) = log {
        unsubscribedCanceller.withLock { $0 = canceller }
        unsubscribedSubId.withLock { $0 = subId }
      }
    }

    let _ = await store.dispatch(.run, snapshot: TestSnapshot.self)

    #expect(unsubscribedCanceller.withLock { $0 } == "canceller")
    #expect(unsubscribedSubId.withLock { $0 } == "target")
  }

  // MARK: - Dispatcher primitive

  /// `tryEnqueue` with a stale `generation` rejects the enqueue.
  @Test
  func tryEnqueueRejectsStaleGeneration() {
    let dispatcher = Store<TestState, TestAction>.Worker.Dispatcher(capacity: 256)
    let staleGeneration = dispatcher.currentGeneration

    dispatcher.flush()

    let result = dispatcher.tryEnqueue(
      id: "x",
      limit: 0,
      generation: staleGeneration,
      (action: TestAction.inc, onSnapshot: nil)
    )

    guard case .failure(.staleGeneration) = result else {
      Issue.record("expected .failure(.staleGeneration), got \(result)")

      return
    }
  }

  /// `tryEnqueue` with matching `generation` rejects when the dispatcher is suspended.
  @Test
  func tryEnqueueHonorsSuspendedEvenWithMatchingGeneration() {
    let dispatcher = Store<TestState, TestAction>.Worker.Dispatcher(capacity: 256)
    dispatcher.suspend()

    let result = dispatcher.tryEnqueue(
      id: "x",
      limit: 0,
      generation: dispatcher.currentGeneration,
      (action: TestAction.inc, onSnapshot: nil)
    )

    guard case .failure(.suspended) = result else {
      Issue.record("expected .failure(.suspended), got \(result)")

      return
    }
  }
}
