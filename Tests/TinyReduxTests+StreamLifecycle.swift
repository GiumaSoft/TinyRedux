//

import Foundation
import Synchronization
import Testing
@testable import TinyRedux


extension TinyReduxTests {

  /// `flush()` eagerly finishes active snapshot streams: the consumer's
  /// `for await` ends promptly and the registry entry is removed.
  @Test
  func flushEndsActiveStream() async {
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

    store.flush()
    await consumer.value

    #expect(store.worker.streams.entries.isEmpty)
  }

  /// `suspend()` eagerly finishes active snapshot streams, and `resume()` does
  /// not revive them: post-resume changes emit nothing.
  @Test
  func suspendEndsActiveStreamAndResumeDoesNotRevive() async {
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

    store.suspend()
    await consumer.value

    #expect(store.worker.streams.entries.isEmpty)

    store.resume()
    store.dispatch(.inc)
    try? await Task.sleep(nanoseconds: 50_000_000)

    #expect(received.withLock { $0 } == 1)
  }

  /// `Store.deinit` eagerly finishes active snapshot streams: the consumer's
  /// `for await` ends instead of hanging, and the Worker — retained by the
  /// stream's termination handler — is released.
  @Test
  func deinitEndsActiveStreamAndReleasesWorker() async {
    var store: Store<TestState, TestAction>? = Self.makeStreamStore()
    weak var worker = store?.worker
    let stream = store!.dispatch(.run, snapshot: SnapshotSpec(
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

    store!.dispatch(.inc)

    await Self.poll { received.withLock { $0 } == 0 }
    #expect(received.withLock { $0 } == 1)

    store = nil
    await consumer.value

    await Self.poll { worker != nil }
    #expect(worker == nil)
  }
}
