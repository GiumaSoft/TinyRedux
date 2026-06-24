//

import Foundation


/// ReduxStoreOptions
///
/// Store-level configuration. Currently holds the **backpressure DIAGNOSTICS** thresholds:
/// the dispatcher buffer stays UNBOUNDED (no drop/reject) — instead a high-frequency
/// detector logs `.highFrequencyAction` when an `action.id` exceeds the configured rate.
/// Defaults are tuned above UI frequency, so the warning fires only on genuine floods.
public struct ReduxStoreOptions: Sendable
{
  /// Sliding window over which occurrences of the same `action.id` are counted.
  public var pressureWindow: Duration

  /// Max occurrences of one `action.id` within `pressureWindow` before warning.
  public var pressureThreshold: Int

  /// Minimum gap between two warnings for the same `action.id` (anti-spam).
  public var pressureCooldown: Duration

  public init(pressureWindow: Duration = .seconds(1),
              pressureThreshold: Int = 120,
              pressureCooldown: Duration = .seconds(5))
  {
    self.pressureWindow = pressureWindow
    self.pressureThreshold = max(1, pressureThreshold)
    self.pressureCooldown = pressureCooldown
  }
}
