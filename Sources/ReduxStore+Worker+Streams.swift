//


import Foundation


extension ReduxStore.Worker
{

  /// Outcome of one ``StreamEntry/tick(_:encoder:)``, carrying just enough for the Worker
  /// to log centrally (so `StreamEntry` stays pure and never captures `onLog`).
  enum TickOutcome: Sendable
  {
    /// The trigger key did not move; nothing was emitted.
    case unchanged

    /// A frame was yielded (`byteCount` bytes of JSON); the stream stays alive.
    case frame(byteCount: Int)

    /// Encoding threw; a `.failure` was yielded, the stream stays alive, and the count
    /// bound was NOT decremented (one bad reading must not kill a live feed).
    case encodeFailed(SendableError)

    /// A frame was yielded AND the count bound is now exhausted → the worker removes it.
    case finished(byteCount: Int)
  }


  /// Streams
  ///
  /// Worker-owned registry of active snapshot-stream entries. Twin of the subscription
  /// registry, but held as a Worker property so `deinit` can eagerly finish every active
  /// stream via ``finishAll()``. `@MainActor`: mutated only on the main actor.
  @MainActor
  final class Streams
  {
    private(set) var entries: [StreamEntry] = []

    nonisolated init() {}

    /// Appends an entry. Ids are unique (auto-`UUID`) — no dedupe.
    func register(_ entry: StreamEntry)
    {
      entries.append(entry)
    }

    /// Removes the entry matching `id`. Returns `true` if removed.
    @discardableResult
    func unregister(id: String) -> Bool
    {
      guard let index = entries.firstIndex(where: { $0.id == id }) else { return false }
      entries.remove(at: index)
      return true
    }

    /// Finishes every active stream and clears the registry (invoked by `deinit`).
    func finishAll()
    {
      entries.forEach { $0.finish() }
      entries.removeAll()
    }
  }


  /// StreamEntry
  ///
  /// Mutable `@MainActor` registry entry of one snapshot stream: edge-trigger cursor, the
  /// type-erased encode closure, the count bound, and the continuation's `yield`/`finish`
  /// endpoints. The `nonisolated init` makes it constructible from the nonisolated stream
  /// `dispatch` body; the class is `Sendable` by `@MainActor` isolation, so it crosses into
  /// the registration `Task`. The `JSONEncoder` is NOT owned here — the Worker passes its
  /// single shared encoder into `tick` (one encoder, one config, no per-entry allocation).
  @MainActor
  final class StreamEntry
  {
    let id: String

    /// Edge-trigger key derived from the read-only state.
    let trigger: @MainActor @Sendable (S.ReadOnly) -> AnyHashable

    /// Last observed trigger key — the edge-trigger cursor.
    var lastKey: AnyHashable?

    /// Snapshot encoder from the spec; the snapshot type is erased inside. Takes the
    /// worker's shared encoder as an argument.
    let encode: @MainActor @Sendable (S.ReadOnly, JSONEncoder) throws -> Data

    /// Yields one frame to the stream continuation.
    let yield: @Sendable (ReduxEncodedSnapshot) -> Void

    /// Finishes the stream continuation.
    let finish: @Sendable () -> Void

    /// Remaining count bound (`.count` / `.timeOrCount`); `nil` = time-only.
    var remaining: UInt?

    nonisolated init( id: String,
                      trigger: @escaping @MainActor @Sendable (S.ReadOnly) -> AnyHashable,
                      encode: @escaping @MainActor @Sendable (S.ReadOnly, JSONEncoder) throws -> Data,
                      yield: @escaping @Sendable (ReduxEncodedSnapshot) -> Void,
                      finish: @escaping @Sendable () -> Void,
                      remaining: UInt? )
    {
      self.id        = id
      self.trigger   = trigger
      self.encode    = encode
      self.yield     = yield
      self.finish    = finish
      self.remaining = remaining
    }

    /// Advances the cursor without emitting (`emitInitial == false`).
    func prime(_ readOnly: S.ReadOnly)
    {
      lastKey = trigger(readOnly)
    }

    /// Emits a frame if the trigger key changed, encoding with the worker's shared encoder.
    func tick(_ readOnly: S.ReadOnly, encoder: JSONEncoder) -> TickOutcome
    {
      let key = trigger(readOnly)
      guard lastKey != key else { return .unchanged }

      lastKey = key                                    // advance even on encode failure
      let data: Data
      do { data = try encode(readOnly, encoder) }
      catch { yield(.failure(error)); return .encodeFailed(error) }   // tolerant: alive, no count

      yield(.success(data))
      guard let remaining else { return .frame(byteCount: data.count) }

      if remaining <= 1                                // <= 1 also guards UInt underflow
      {
        finish()
        return .finished(byteCount: data.count)
      }
      self.remaining = remaining - 1
      return .frame(byteCount: data.count)
    }
  }
}
