//


import Foundation


/// SnapshotSpec
///
/// Transportable, `Sendable` specification of a snapshot stream: what to capture, when
/// to emit, and how the stream is bounded. Passed to the streaming overload of
/// `dispatch(_:snapshot:)`. The snapshot type `T` is erased at construction (baked into
/// `encode`), so the spec is generic only over the state `S`.
///
/// - `changeOn`: edge-trigger key — a frame is emitted only when the key changes at a
///   reduce terminal.
/// - `emitInitial`: emit the current state at registration time (default `false`).
/// - `limit`: **required** bound — every stream is finite (`count` / `time` /
///   `timeOrCount`). Consumer cancellation and `deinit` are additional early-termination
///   sources.
public struct SnapshotSpec<S>: Sendable where S: ReduxState
{
  /// Required stream bound. Consumer cancel / `deinit` are additional early terminations.
  public enum Limit: Sendable
  {
    /// Ends after the first `N` successfully-encoded frames.
    case count(UInt)

    /// Ends when the time window elapses.
    case time(Duration)

    /// Ends at whichever of the two bounds is reached first.
    case timeOrCount(Duration, UInt)

    /// `true` when any count bound is positive. A zero count is rejected in debug
    /// builds; in release the stream finishes immediately, emitting no frame.
    var hasPositiveCountBound: Bool {
      switch self
      {
        case .count(let n), .timeOrCount(_, let n): return n > 0
        case .time:                                 return true
      }
    }
  }

  /// Edge-trigger key derived from the read-only state, erased to `AnyHashable`.
  let trigger: @MainActor @Sendable (S.ReadOnly) -> AnyHashable

  /// Snapshot encoder with the snapshot type erased; the per-stream `JSONEncoder` is
  /// passed in as an argument so no `@Sendable` closure captures it.
  let encode: @MainActor @Sendable (S.ReadOnly, JSONEncoder) throws -> Data

  /// Emits the current state at registration when `true`.
  let emitInitial: Bool

  /// Required stream bound.
  let limit: Limit

  /// Creates a snapshot-stream specification.
  ///
  /// - Parameters:
  ///   - snapshot: The ``ReduxStateSnapshot`` conformer whose `init(state:)` captures
  ///     the relevant state slice on each emission.
  ///   - key: Edge-trigger key derived from the read-only state; a frame is emitted when
  ///     the key differs from the previously observed one. Choose a key that tracks what
  ///     the snapshot captures, or a key change emits duplicate content.
  ///   - emitInitial: Emit the current state at registration. Defaults to `false`.
  ///   - limit: Required stream bound.
  public init<T, K>( _ snapshot: T.Type,
                     changeOn key: @escaping @MainActor @Sendable (S.ReadOnly) -> K,
                     emitInitial: Bool = false,
                     limit: Limit )
  where T: ReduxStateSnapshot<S>, K: Hashable & Sendable
  {
    assert(limit.hasPositiveCountBound, "SnapshotSpec.Limit count bound must be greater than 0")
    self.trigger     = { AnyHashable(key($0)) }
    self.encode      = { try $1.encode(T(state: $0)) }
    self.emitInitial = emitInitial
    self.limit       = limit
  }

  /// Creates a snapshot-stream specification from a builder closure, for snapshot shapes
  /// that need call-site context beyond the state (e.g. a resolved target reference baked
  /// in alongside the read-only state).
  ///
  /// - Parameters:
  ///   - build: Builds the snapshot value captured on each emission.
  ///   - key: Edge-trigger key derived from the read-only state; a frame is emitted when
  ///     the key differs from the previously observed one.
  ///   - emitInitial: Emit the current state at registration. Defaults to `false`.
  ///   - limit: Required stream bound.
  public init<T, K>( build: @escaping @MainActor @Sendable (S.ReadOnly) -> T,
                     changeOn key: @escaping @MainActor @Sendable (S.ReadOnly) -> K,
                     emitInitial: Bool = false,
                     limit: Limit )
  where T: ReduxStateSnapshot<S>, K: Hashable & Sendable
  {
    assert(limit.hasPositiveCountBound, "SnapshotSpec.Limit count bound must be greater than 0")
    self.trigger     = { AnyHashable(key($0)) }
    self.encode      = { try $1.encode(build($0)) }
    self.emitInitial = emitInitial
    self.limit       = limit
  }
}
