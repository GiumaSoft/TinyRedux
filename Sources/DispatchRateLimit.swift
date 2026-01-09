//


import Foundation


/// DispatchRateLimit
///
/// Opt-in, per-dispatch rate control for high-frequency SAMPLE-STREAM actions (AR frames,
/// sensors). Default `.none` → unbounded, never dropped (logical actions stay deterministic
/// / replayable). Drops are observable (logged). Distinct from the rejected
/// capacity/suspend/generation cluster. See memory `redux-rate-control`.
public enum DispatchRateLimit: Sendable
{
  /// No limit: the action always enters the queue (default).
  case none

  /// At most `N` actions with the same `id` pending (un-reduced); drops the NEW one when
  /// full. Queue-depth gate — effective only when the REDUCE loop is the bottleneck.
  case limit(Int)

  /// At most one action per `id` per time window (leading edge): drops actions arriving
  /// within `Duration` of the last admitted one. Time gate — caps the dispatch rate.
  case throttle(Duration)
}
