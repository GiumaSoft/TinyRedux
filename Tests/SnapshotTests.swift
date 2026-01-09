//
//  Snapshot dispatch: single-shot `dispatch(_:snapshot:)` (one settled, encoded value at the
//  pipeline terminal) and the stream `dispatch(_:snapshot:)` (edge-triggered, bounded feed of
//  the same projection). Captures are JSON `Data`, decoded back to the same conformer.
//

import Testing
import Foundation
@testable import TinyRedux


/// Snapshot of the counter slice.
struct CounterSnapshot: ReduxStateSnapshot
{
  typealias S = AppState
  let counter: Int

  @MainActor init(state: AppState.ReadOnly) { self.counter = state.counter }
}


/// Snapshot whose encoding throws when `counter == 2` (`JSONEncoder` rejects `.nan`),
/// exercising the per-frame encode-failure tolerance.
struct NaNSnapshot: ReduxStateSnapshot
{
  typealias S = AppState
  let value: Double

  @MainActor init(state: AppState.ReadOnly) { self.value = state.counter == 2 ? .nan : Double(state.counter) }
}


private func counters(_ frames: [ReduxEncodedSnapshot]) -> [Int]
{
  frames.compactMap { frame in
    guard case .success(let data) = frame else { return nil }
    return try? JSONDecoder().decode(CounterSnapshot.self, from: data).counter
  }
}

private func values(_ frames: [ReduxEncodedSnapshot]) -> [Int]
{
  frames.compactMap { frame in
    guard case .success(let data) = frame else { return nil }
    return (try? JSONDecoder().decode(NaNSnapshot.self, from: data)).map { Int($0.value) }
  }
}


// MARK: - Single-shot

@MainActor
@Test
func snapshot_resolvesAfterReduce() async throws
{
  let store = ReduxStore(initialState: AppState(), reducers: [mainReducer])

  let result = await store.dispatch(.increment, snapshot: CounterSnapshot.self)

  let data = try result.get()
  #expect(try JSONDecoder().decode(CounterSnapshot.self, from: data).counter == 1)
}


@MainActor
@Test
func snapshot_exitDoneResolvesWithoutReduce() async throws
{
  // Middleware absorbs the action (`.exit(.done)`): no reduce, but the continuation MUST
  // still resolve (else the caller hangs forever).
  let absorb = AnyMiddleware<AppState, AppActions>(id: "absorb") { _ in .exit(.done) }
  let store = ReduxStore(initialState: AppState(), reducers: [mainReducer], middlewares: [absorb])

  let result = await store.dispatch(.increment, snapshot: CounterSnapshot.self)

  let data = try result.get()
  #expect(try JSONDecoder().decode(CounterSnapshot.self, from: data).counter == 0)   // not reduced
  #expect(store.counter == 0)
}


@MainActor
@Test
func snapshot_unhandledErrorFails() async
{
  // Middleware routes to the resolver; with no resolver the default fail terminates → the
  // single-shot resolves to `.failure`.
  let boom = AnyMiddleware<AppState, AppActions>(id: "boom") { _ in .exit(.resolve(TestError.boom)) }
  let store = ReduxStore(initialState: AppState(), reducers: [mainReducer], middlewares: [boom])

  let result = await store.dispatch(.increment, snapshot: CounterSnapshot.self)

  guard case .failure(let error) = result else { Issue.record("expected .failure"); return }
  #expect(error as? TestError == .boom)
  #expect(store.counter == 0)
}


@MainActor
@Test
func snapshot_deferredResumeResolves() async throws
{
  // A suspending effect resumes the chain; the terminal must fire on the resumed reduce.
  let effect = AnyMiddleware<AppState, AppActions>(id: "effect")
  { context in
    if case .increment = context.action { return .deferred { _ in .next } }
    return .next
  }
  let store = ReduxStore(initialState: AppState(), reducers: [mainReducer], middlewares: [effect])

  let result = await store.dispatch(.increment, snapshot: CounterSnapshot.self)

  #expect(try JSONDecoder().decode(CounterSnapshot.self, from: result.get()).counter == 1)
}


// MARK: - Stream

@MainActor
@Test
func stream_emitsFrameOnTriggerChange() async
{
  let store = ReduxStore(initialState: AppState(), reducers: [mainReducer])

  let stream = store.dispatch(.increment, snapshot: SnapshotSpec(
    CounterSnapshot.self, changeOn: { $0.counter }, limit: .count(1)))

  var frames: [ReduxEncodedSnapshot] = []
  for await frame in stream { frames.append(frame) }

  #expect(counters(frames) == [1])               // arming reduced 0→1 → one frame, count bound met
}


@MainActor
@Test
func stream_emitInitialEmitsCurrentThenBounds() async
{
  let store = ReduxStore(initialState: AppState(), reducers: [mainReducer])

  let stream = store.dispatch(.increment, snapshot: SnapshotSpec(
    CounterSnapshot.self, changeOn: { $0.counter }, emitInitial: true, limit: .count(1)))

  var frames: [ReduxEncodedSnapshot] = []
  for await frame in stream { frames.append(frame) }

  #expect(counters(frames) == [0])               // initial state emitted; count(1) met before arming reduces
}


@MainActor
@Test
func stream_countBoundsTheSequence() async
{
  let store = ReduxStore(initialState: AppState(), reducers: [mainReducer])

  let stream = store.dispatch(.increment, snapshot: SnapshotSpec(
    CounterSnapshot.self, changeOn: { $0.counter }, limit: .count(2)))

  var frames: [ReduxEncodedSnapshot] = []
  for await frame in stream
  {
    frames.append(frame)
    store.dispatch(.increment)                    // drive the next change once the stream is live
  }

  #expect(counters(frames) == [1, 2])            // exactly two frames, then bounded
}


@MainActor
@Test
func stream_edgeTriggerSkipsUnchangedKey() async
{
  let store = ReduxStore(initialState: AppState(), reducers: [mainReducer])

  // Trigger key is constant → after priming, no reduce ever changes it: only `emitInitial`
  // produces a frame, and the count bound is then met.
  let stream = store.dispatch(.increment, snapshot: SnapshotSpec(
    CounterSnapshot.self, changeOn: { _ in 0 }, emitInitial: true, limit: .count(1)))

  var frames: [ReduxEncodedSnapshot] = []
  for await frame in stream
  {
    frames.append(frame)
    store.dispatch(.increment)                    // changes counter but NOT the constant key
  }

  #expect(counters(frames) == [0])               // only the initial frame; subsequent reduces skipped
}


@MainActor
@Test
func stream_encodeFailureToleratedNotCounted() async
{
  let store = ReduxStore(initialState: AppState(), reducers: [mainReducer])

  let stream = store.dispatch(.increment, snapshot: SnapshotSpec(
    NaNSnapshot.self, changeOn: { $0.counter }, limit: .count(2)))

  var frames: [ReduxEncodedSnapshot] = []
  for await frame in stream
  {
    frames.append(frame)
    store.dispatch(.increment)
  }

  // counter 1 (ok), 2 (NaN → encode fails, .failure, NOT counted), 3 (ok) → two successes.
  #expect(frames.count == 3)
  #expect(values(frames) == [1, 3])
  if case .failure = frames[1] {} else { Issue.record("frame 2 should be a .failure (NaN encode)") }
}


@MainActor
@Test
func stream_timeBoundEndsTheStream() async
{
  let store = ReduxStore(initialState: AppState(), reducers: [mainReducer])

  let stream = store.dispatch(.increment, snapshot: SnapshotSpec(
    CounterSnapshot.self, changeOn: { $0.counter }, limit: .time(.milliseconds(50))))

  var frames: [ReduxEncodedSnapshot] = []
  for await frame in stream { frames.append(frame) }   // ends when the time window elapses

  #expect(counters(frames) == [1])
}


@MainActor
@Test
func stream_consumerCancelUnregisters() async
{
  let store = ReduxStore(initialState: AppState(), reducers: [mainReducer])

  // Create AND consume the stream inside the task: when the task returns it is the only
  // owner, so the stream is released → `onTermination` fires (a retained value would not).
  let received = await Task { @MainActor in
    var n = 0
    let stream = store.dispatch(.increment, snapshot: SnapshotSpec(
      CounterSnapshot.self, changeOn: { $0.counter }, limit: .count(100)))
    for await _ in stream { n += 1; break }        // cancel after the first frame
    return n
  }.value

  #expect(received == 1)
  await waitUntil { store.worker.streams.entries.isEmpty }
  #expect(store.worker.streams.entries.isEmpty)    // onTermination dropped the entry
}


@MainActor
@Test
func stream_finishesOnStoreTeardown() async
{
  var store: ReduxStore<AppState, AppActions>? =
    ReduxStore(initialState: AppState(), reducers: [mainReducer])

  let stream = store!.dispatch(.increment, snapshot: SnapshotSpec(
    CounterSnapshot.self, changeOn: { $0.counter }, limit: .count(100)))   // far from its bound

  let started = Box()
  let done = Box()
  let task = Task { @MainActor in
    var n = 0
    for await _ in stream { if n == 0 { started.mark() }; n += 1 }
    done.mark()
    return n
  }

  await waitUntil { started.flag }                 // stream registered + first frame in
  store = nil                                      // release → ReduxStore.deinit → finishAllStreams
  await waitUntil { done.flag }                    // the for-await ended (no hang)

  let n = await task.value
  #expect(done.flag)
  #expect(n >= 1)
}
