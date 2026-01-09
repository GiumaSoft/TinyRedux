//
//  Example log sink: maps TinyRedux's structured `ReduxLog` onto `os.Logger`
//  (Sendable + thread-safe). This is the app's choice of sink — the library core
//  only emits typed events and never assumes a destination.
//

import OSLog
import TinyRedux


enum AppLog
{
  static let logger = Logger(subsystem: "com.gmsoft.TinyRedux.Example", category: "redux")

  /// `@Sendable` handler passed to `ReduxStore(onLog:)`.
  @Sendable
  static func handle(_ event: ReduxLog<AppState, AppActions>)
  {
    let line: String
    switch event
    {
    case let .reducer(id, action, duration, exit):
      line = "↩️ reducer[\(id)] · \(action.id) · \(duration) · \(exit)"
    case let .middleware(id, action, duration, exit):
      line = "⚙️ middleware[\(id)] · \(action.id) · \(duration) · \(exit)"
    case let .resolver(id, action, duration, exit, error):
      line = "🛟 resolver[\(id)] · \(action.id) · \(duration) · \(exit) · \(error)"
    case let .subscription(event):
      line = "🔔 subscription · \(event)"
    case let .snapshot(event):
      line = "📸 snapshot · \(event)"
    case let .highFrequencyAction(id, count, window):
      line = "⚠️ high-frequency · \(id) · \(count)× in \(window)"
    case let .store(message):
      line = "🏬 store · \(message)"
    @unknown default:
      line = "• \(String(describing: event))"
    }
    logger.log("\(line, privacy: .public)")
  }
}
