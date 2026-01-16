// swift-tools-version: 6.0


import Foundation


extension Store {
  /// Current monotonic time in nanoseconds for performance measurement.
  var currentTime: UInt64 { DispatchTime.now().uptimeNanoseconds }
  /// Comma-separated debug list of queued actions.
  var remainingActions: String {
    actionBuffer
      .map { ".\($0)" }
      .joined(separator: ",")
  }
  /// Measures elapsed execution time for the supplied block, providing a lazy timer closure so
  /// callers can log durations after work completes without allocating intermediate state or
  /// capturing extra values unnecessarily. Measures execution time in milliseconds and passes a
  /// lazy timer to the block.
  func measurePerformance(_ block: @escaping (_ runTime: @escaping () -> UInt64) throws -> Void) rethrows {
    let startTime = currentTime
    try block {
      return (self.currentTime - startTime) / 1_000_000
    }
  }
}
