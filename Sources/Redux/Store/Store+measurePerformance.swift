// swift-tools-version: 6.0


import Foundation


extension Store {
  /// Comma-separated debug list of queued actions.
  var remainingActions: String {
    actionBuffer
      .map { ".\($0)" }
      .joined(separator: ",")
  }
  /// Measures elapsed execution time for the supplied block, providing a lazy timer closure so
  /// callers can log durations after work completes without allocating intermediate state or
  /// capturing extra values unnecessarily. Measures execution time in milliseconds and passes a
  /// lazy timer to the block. Each invocation of the timer returns the elapsed time since the
  /// previous invocation (or since start for the first call).
  func measurePerformance(_ block: @escaping (_ runTime: @escaping () -> UInt64) throws -> Void) rethrows {
    /// Current monotonic time in nanoseconds for performance measurement.
    var now: UInt64 { DispatchTime.now().uptimeNanoseconds }
    var lastTime = now
    try block {
      let current = now
      defer { lastTime = current }
      return (current - lastTime) / 1_000_000
    }
  }
}
