//


import Foundation


extension Store.Worker {

  /// Streams
  ///
  /// Collection of active snapshot-stream entries owned by the Worker. Twin of
  /// ``Subscriptions``, but held as a Worker property (not a build-local) so
  /// `flush`/`suspend`/`deinit` can eagerly finish every active stream via
  /// ``finishAll()``.
  @MainActor
  final class Streams {

    var entries: [StreamEntry] = []

    nonisolated init() {}

    /// Appends an entry. Ids are unique (auto-`UUID`) — no dedupe.
    func register(_ entry: StreamEntry) {
      entries.append(entry)
    }

    /// Removes the entry matching `id`. Returns `true` if removed, `false` if not present.
    @discardableResult
    func unregister(id: String) -> Bool {
      guard let index = entries.firstIndex(where: { $0.id == id }) else {

        return false
      }

      entries.remove(at: index)

      return true
    }

    /// Finishes every active stream and clears the registry. Invoked by
    /// `flush`/`suspend`/`deinit` so consumers' `for await` loops end promptly.
    func finishAll() {
      entries.forEach { $0.finish() }
      entries.removeAll()
    }
  }

  /// StreamEntry
  ///
  /// Mutable `@MainActor` registry entry of one snapshot stream: edge-trigger
  /// cursor, per-stream encoder, count bound, and the continuation's
  /// `yield`/`finish` endpoints. The `nonisolated init` makes the entry
  /// constructible from the nonisolated `dispatch` body; the class is Sendable
  /// by `@MainActor` isolation, so it crosses into the registration `Task`.
  @MainActor
  final class StreamEntry {

    /// Auto-generated `UUID` string identifying this stream.
    let id: String

    /// Edge-trigger key derived from the read-only state.
    let trigger: @MainActor @Sendable (S.ReadOnly) -> AnyHashable

    /// Last observed trigger key — the edge-trigger cursor.
    var lastKey: AnyHashable?

    /// Per-stream encoder, passed as an argument to `encode` so no `@Sendable`
    /// closure captures it.
    let encoder: JSONEncoder

    /// Snapshot encoder from the spec; the snapshot type is erased inside.
    let encode: @MainActor @Sendable (S.ReadOnly, JSONEncoder) throws -> Data

    /// Yields one frame to the stream continuation.
    let yield: @Sendable (ReduxEncodedSnapshot) -> Void

    /// Finishes the stream continuation.
    let finish: @Sendable () -> Void

    /// Remaining count bound (`.count` / `.timeOrCount`); `nil` = time-only.
    var remaining: UInt?

    nonisolated init(
      id: String,
      trigger: @escaping @MainActor @Sendable (S.ReadOnly) -> AnyHashable,
      encode: @escaping @MainActor @Sendable (S.ReadOnly, JSONEncoder) throws -> Data,
      yield: @escaping @Sendable (ReduxEncodedSnapshot) -> Void,
      finish: @escaping @Sendable () -> Void,
      remaining: UInt?
    ) {
      self.id = id
      self.trigger = trigger
      self.encode = encode
      self.yield = yield
      self.finish = finish
      self.remaining = remaining
      self.encoder = JSONEncoder()
    }

    /// Advances the cursor without emitting (`emitInitial == false`).
    func prime(_ readOnly: S.ReadOnly) {
      lastKey = trigger(readOnly)
    }

    /// Emits a frame if the trigger key changed. Returns `true` when the entry
    /// is exhausted (the caller removes it). A frame that fails to encode is
    /// yielded as `.failure`, does **not** count toward the bound, and keeps
    /// the stream alive — one bad reading must not kill a live telemetry feed.
    func tick(_ readOnly: S.ReadOnly) -> Bool {
      let key = trigger(readOnly)
      guard lastKey != key else {

        return false
      }

      /// Advance even on encode failure: the change was observed.
      lastKey = key
      let data: Data

      do {
        data = try encode(readOnly, encoder)
      } catch {
        yield(.failure(error))

        return false
      }

      yield(.success(data))
      guard let remaining else {

        return false
      }

      /// `remaining <= 1` also guards `UInt` underflow on the last frame.
      if remaining <= 1 {
        finish()

        return true
      }

      self.remaining = remaining - 1

      return false
    }
  }
}
