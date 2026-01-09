//

import Foundation
import Synchronization
import Testing
@testable import TinyRedux


/// Snapshot whose encoding throws when `value == 2`: `JSONEncoder` rejects
/// `.nan` by default — exercises the per-frame encode-failure path (§8.1).
struct NaNSnapshot: ReduxStateSnapshot {
  typealias S = TestState
  let value: Double

  @MainActor
  init(state: TestReadOnly) {
    self.value = state.value == 2 ? .nan : Double(state.value)
  }
}


extension TinyReduxTests {

  static func makeStreamStore() -> Store<TestState, TestAction> {
    let reducer = AnyReducer<TestState, TestAction>(id: "stream") { context in
      switch context.action {
      case .inc:
        context.state.value += 1

      case .run:
        context.state.log.append("run")
      }

      return .next
    }

    return Store(
      initialState: TestState(),
      middlewares: [],
      resolvers: [],
      reducers: [reducer]
    )
  }

  static func decodeValues(_ frames: [ReduxEncodedSnapshot]) -> [Int] {
    frames.compactMap { frame in
      guard case .success(let data) = frame else {

        return nil
      }

      return try? JSONDecoder().decode(TestSnapshot.self, from: data).value
    }
  }

  /// The `dispatch(_:snapshot:)` overload pair resolves by argument type:
  /// `Type.self` → one async `Result`, `SnapshotSpec(…)` → an `AsyncStream`.
  @Test
  func snapshotOverloadResolvesByArgumentType() async {
    let store = Self.makeStreamStore()

    let single = await store.dispatch(.inc, snapshot: TestSnapshot.self)
    #expect((try? single.get()) != nil)

    let stream: AsyncStream<ReduxEncodedSnapshot> = store.dispatch(.inc, snapshot: SnapshotSpec(
      TestSnapshot.self,
      changeOn: { $0.value },
      limit: .count(1)
    ))
    var frames: [ReduxEncodedSnapshot] = []

    for await frame in stream {
      frames.append(frame)
    }

    #expect(Self.decodeValues(frames) == [2])
  }

  /// Edge-trigger: a frame is emitted only when the `changeOn` key changes.
  /// `.run` mutates `log` (a reduce terminal) but not `value`, so it must not
  /// emit a duplicate frame.
  @Test
  func streamEmitsOnlyWhenTriggerKeyChanges() async {
    let store = Self.makeStreamStore()
    let stream = store.dispatch(.run, snapshot: SnapshotSpec(
      TestSnapshot.self,
      changeOn: { $0.value },
      limit: .count(2)
    ))

    store.dispatch(.run)
    store.dispatch(.inc)
    store.dispatch(.run)
    store.dispatch(.inc)

    var frames: [ReduxEncodedSnapshot] = []

    for await frame in stream {
      frames.append(frame)
    }

    #expect(Self.decodeValues(frames) == [1, 2])
  }

  /// `emitInitial: true` emits the current state at registration, even when the
  /// arming action never reaches a reduce terminal (middleware `.exit(.done)`).
  @Test
  func streamEmitInitialEmitsAtRegistration() async {
    let middleware = AnyMiddleware<TestState, TestAction>(id: "armer") { context in
      context.action == .run ? .exit(.done) : .next
    }
    let store = Store(
      initialState: TestState(),
      middlewares: [middleware],
      resolvers: [],
      reducers: []
    )
    let stream = store.dispatch(.run, snapshot: SnapshotSpec(
      TestSnapshot.self,
      changeOn: { $0.value },
      emitInitial: true,
      limit: .count(1)
    ))
    var frames: [ReduxEncodedSnapshot] = []

    for await frame in stream {
      frames.append(frame)
    }

    #expect(Self.decodeValues(frames) == [0])
  }

  /// `emitInitial: false` (default) primes the cursor: the first frame is the
  /// first *change*, not the registration-time state.
  @Test
  func streamEmitInitialFalseWaitsForFirstChange() async {
    let store = Self.makeStreamStore()
    let stream = store.dispatch(.run, snapshot: SnapshotSpec(
      TestSnapshot.self,
      changeOn: { $0.value },
      limit: .count(1)
    ))

    store.dispatch(.inc)

    var frames: [ReduxEncodedSnapshot] = []

    for await frame in stream {
      frames.append(frame)
    }

    #expect(Self.decodeValues(frames) == [1])
  }

  /// `.count(N)` ends the stream after exactly N frames; further changes are
  /// not delivered.
  @Test
  func streamCountLimitEndsAfterNFrames() async {
    let store = Self.makeStreamStore()
    let stream = store.dispatch(.run, snapshot: SnapshotSpec(
      TestSnapshot.self,
      changeOn: { $0.value },
      limit: .count(3)
    ))

    for _ in 0..<5 { store.dispatch(.inc) }

    var frames: [ReduxEncodedSnapshot] = []

    for await frame in stream {
      frames.append(frame)
    }

    #expect(Self.decodeValues(frames) == [1, 2, 3])
    await Self.poll { !store.worker.streams.entries.isEmpty }
    #expect(store.worker.streams.entries.isEmpty)
  }

  /// `.time(d)` ends the stream when the window elapses, delivering whatever
  /// was emitted in the meantime.
  @Test
  func streamTimeLimitEndsAfterWindow() async {
    let store = Self.makeStreamStore()
    let stream = store.dispatch(.run, snapshot: SnapshotSpec(
      TestSnapshot.self,
      changeOn: { $0.value },
      limit: .time(.milliseconds(100))
    ))

    store.dispatch(.inc)

    var frames: [ReduxEncodedSnapshot] = []

    for await frame in stream {
      frames.append(frame)
    }

    #expect(Self.decodeValues(frames) == [1])
  }

  /// `.timeOrCount` ends at whichever bound is reached first — here the count,
  /// well before the long time window.
  @Test
  func streamTimeOrCountEndsAtCountFirst() async {
    let store = Self.makeStreamStore()
    let start: ContinuousClock.Instant = .now
    let stream = store.dispatch(.run, snapshot: SnapshotSpec(
      TestSnapshot.self,
      changeOn: { $0.value },
      limit: .timeOrCount(.seconds(60), 2)
    ))

    store.dispatch(.inc)
    store.dispatch(.inc)

    var frames: [ReduxEncodedSnapshot] = []

    for await frame in stream {
      frames.append(frame)
    }

    #expect(Self.decodeValues(frames) == [1, 2])
    #expect(.now - start < .seconds(30))
  }

  /// `.timeOrCount` ends at the time bound when the count is never reached.
  @Test
  func streamTimeOrCountEndsAtTimeFirst() async {
    let store = Self.makeStreamStore()
    let stream = store.dispatch(.run, snapshot: SnapshotSpec(
      TestSnapshot.self,
      changeOn: { $0.value },
      limit: .timeOrCount(.milliseconds(100), 100)
    ))

    store.dispatch(.inc)

    var frames: [ReduxEncodedSnapshot] = []

    for await frame in stream {
      frames.append(frame)
    }

    #expect(Self.decodeValues(frames) == [1])
  }

  /// Unbounded buffer: every frame is buffered and delivered in order even when
  /// the consumer starts late — no frame loss.
  @Test
  func streamUnboundedBufferDeliversEveryFrameInOrder() async {
    let store = Self.makeStreamStore()
    let stream = store.dispatch(.run, snapshot: SnapshotSpec(
      TestSnapshot.self,
      changeOn: { $0.value },
      limit: .count(10)
    ))

    for _ in 0..<10 { store.dispatch(.inc) }

    /// Let the pipeline emit everything before consuming a single frame.
    await Self.poll { store.worker.dispatcher.pendingCount > 0 }

    var frames: [ReduxEncodedSnapshot] = []

    for await frame in stream {
      frames.append(frame)
    }

    #expect(Self.decodeValues(frames) == Array(1...10))
  }

  /// A frame that fails to encode is yielded as `.failure`, does not count
  /// toward `.count`, and the stream keeps emitting subsequent frames.
  @Test
  func streamEncodeFailureDoesNotCountAndStreamContinues() async {
    let store = Self.makeStreamStore()
    let stream = store.dispatch(.run, snapshot: SnapshotSpec(
      NaNSnapshot.self,
      changeOn: { $0.value },
      limit: .count(2)
    ))

    store.dispatch(.inc)
    store.dispatch(.inc)
    store.dispatch(.inc)

    var successes: [Double] = []
    var failures = 0

    for await frame in stream {
      switch frame {
      case .success(let data):
        if let snapshot = try? JSONDecoder().decode(NaNSnapshot.self, from: data) {
          successes.append(snapshot.value)
        }

      case .failure:
        failures += 1
      }
    }

    #expect(successes == [1.0, 3.0])
    #expect(failures == 1)
  }

  /// A long-lived stream holds no dispatcher admission slot: after the pipeline
  /// drains, `pendingCount` is back to zero while the stream is still active.
  @Test
  func streamHoldsNoAdmissionSlot() async {
    let store = Self.makeStreamStore()
    let stream = store.dispatch(.run, snapshot: SnapshotSpec(
      TestSnapshot.self,
      changeOn: { $0.value },
      limit: .count(100)
    ))
    let consumer = Task { @MainActor in
      var count = 0

      for await _ in stream {
        count += 1
      }

      return count
    }

    let result = await store.dispatchAndDecode(.inc)

    #expect(result.value == 1)
    #expect(store.worker.dispatcher.pendingCount == 0)
    #expect(store.worker.streams.entries.count == 1)

    consumer.cancel()
    _ = await consumer.value
  }

  /// Cancelling the consuming task triggers `onTermination`, which unregisters
  /// the entry — no further emission, no leaked registry entry.
  @Test
  func streamCallerCancelUnregistersEntry() async {
    let store = Self.makeStreamStore()
    let stream = store.dispatch(.run, snapshot: SnapshotSpec(
      TestSnapshot.self,
      changeOn: { $0.value },
      limit: .count(100)
    ))
    let received = Mutex<Int>(0)
    let consumer = Task { @MainActor in
      for await _ in stream {
        received.withLock { $0 += 1 }
      }
    }

    store.dispatch(.inc)

    await Self.poll { received.withLock { $0 } == 0 }
    #expect(received.withLock { $0 } == 1)

    consumer.cancel()
    await consumer.value

    await Self.poll { !store.worker.streams.entries.isEmpty }
    #expect(store.worker.streams.entries.isEmpty)

    /// A change after cancellation must not reach the cancelled consumer.
    store.dispatch(.inc)
    try? await Task.sleep(nanoseconds: 50_000_000)
    #expect(received.withLock { $0 } == 1)
  }

  /// The streaming overload bounded by `limit: .count(1)` yields exactly the SAME
  /// snapshot as the one-shot `dispatch(_:snapshot:)` for the same action — the
  /// single-shot is the degenerate "stream of length 1". Equivalence holds with
  /// `emitInitial: false` (default): the spec arms on `.inc` (value 0→1) and emits
  /// one frame = snapshot(value: 1), identical to the one-shot capture.
  @Test
  func streamCountOneEqualsOneShotSnapshot() async {
    // one-shot: dispatch(_:snapshot: T.self) → a single decoded snapshot
    let oneShot = await Self.makeStreamStore().dispatchAndDecode(.inc)

    // stream: dispatch(_:snapshot: SnapshotSpec(… limit: .count(1))) → one frame.
    // The store must be held for the whole `for await`: a released store deinits and
    // `finishAllStreams()` (N1) would end the stream before it emits.
    let store = Self.makeStreamStore()
    var frames: [ReduxEncodedSnapshot] = []
    for await frame in store.dispatch(.inc, snapshot: SnapshotSpec(
      TestSnapshot.self,
      changeOn: { $0.value },
      limit: .count(1)
    )) {
      frames.append(frame)
    }
    withExtendedLifetime(store) {}

    #expect(Self.decodeValues(frames) == [oneShot.value])   // stream .count(1) == one-shot
    #expect(oneShot.value == 1)
  }
}
