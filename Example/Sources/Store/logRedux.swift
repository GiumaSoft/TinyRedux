//
//  Console log sink equivalent to main's `logRedux`, adapted to the current `ReduxLog`
//  (OSLog backend). Each pipeline component logs id / action / duration / exit at `.info`,
//  failures at `.error`. Extends main's coverage to the dev-only events (snapshot,
//  backpressure). Pass it as `ReduxStore(onLog:)`: `onLog: logRedux`.
//

import Foundation
import OSLog
import TinyRedux


@MainActor
public func logRedux<S, A>(_ log: ReduxLog<S, A>) where S: ReduxState, A: ReduxAction
{
  switch log
  {
    // ── MIDDLEWARE ────────────────────────────────────────────────────────────────────
    case let .middleware(id, action, duration, .next):
      emit(.info, "MIDDLEWARE", "processed action", id: id, action: action, duration: duration, exit: "next")
    case let .middleware(id, action, duration, .nextAs(new)):
      emit(.info, "MIDDLEWARE", "processed action", id: id, action: action, duration: duration, exit: "nextAs(\(new.id))")
    case let .middleware(id, action, duration, .exit(.reduce)):
      emit(.info, "MIDDLEWARE", "processed action", id: id, action: action, duration: duration, exit: "exit(.reduce)")
    case let .middleware(id, action, duration, .exit(.reduceAs(new))):
      emit(.info, "MIDDLEWARE", "processed action", id: id, action: action, duration: duration, exit: "exit(.reduceAs(\(new.id)))")
    case let .middleware(id, action, duration, .exit(.resolve(error))):
      emit(.error, "MIDDLEWARE", "failed to process action; forwarded to resolver", id: id, action: action, duration: duration, exit: "exit(.resolve)", error: error)
    case let .middleware(id, action, duration, .exit(.done)):
      emit(.info, "MIDDLEWARE", "processed action and exited pipeline", id: id, action: action, duration: duration, exit: "exit(.done)")
    case .middleware(_, _, _, .defaultNext),    // "not mine" — never emitted, but stay exhaustive
         .middleware(_, _, _, .task),
         .middleware(_, _, _, .deferred):
      break

    // ── REDUCER ───────────────────────────────────────────────────────────────────────
    case let .reducer(id, action, duration, .next):
      emit(.info, "REDUCER", "mutated state", id: id, action: action, duration: duration, exit: "next")
    case let .reducer(id, action, duration, .done):
      emit(.info, "REDUCER", "mutated state", id: id, action: action, duration: duration, exit: "done")
    case .reducer(_, _, _, .defaultNext):
      break

    // ── RESOLVER ──────────────────────────────────────────────────────────────────────
    case let .resolver(id, action, duration, .exit(.reduce), error):
      emit(.info, "RESOLVER", "resolved error", id: id, action: action, duration: duration, exit: "exit(.reduce)", error: error)
    case let .resolver(id, action, duration, .exit(.reduceAs(new)), error):
      emit(.info, "RESOLVER", "resolved error", id: id, action: action, duration: duration, exit: "exit(.reduceAs(\(new.id)))", error: error)
    case let .resolver(id, action, duration, .exit(.done), error):
      emit(.info, "RESOLVER", "resolved error (absorbed)", id: id, action: action, duration: duration, exit: "exit(.done)", error: error)
    case let .resolver(id, action, duration, .exit(.fail(resolved)), _):
      emit(.error, "RESOLVER", "failed to resolve error", id: id, action: action, duration: duration, exit: "exit(.fail)", error: resolved)
    case .resolver(_, _, _, .defaultNext, _):
      break

    // ── SUBSCRIPTION ──────────────────────────────────────────────────────────────────
    case let .subscription(.subscribed(_, subId, registeredBy, duration)):
      emit(.info, "SUBSCRIPTION", "register subscription \(subId)", id: subId, action: registeredBy, duration: duration)
    case let .subscription(.executed(_, subId, registeredBy, duration, trigger)):
      emit(.info, "SUBSCRIPTION", "fire subscription \(subId) → dispatch \(trigger.id)", id: subId, action: registeredBy, duration: duration)
    case let .subscription(.unsubscribed(_, subId, duration)):
      emit(.info, "SUBSCRIPTION", "unregister subscription \(subId)", id: subId, duration: duration)

    // ── SNAPSHOT (dev) ────────────────────────────────────────────────────────────────
    case let .snapshot(.resolved(action, byteCount, duration)):
      emit(.info, "SNAPSHOT", "single-shot resolved (\(byteCount) B)", action: action, duration: duration, exit: "success")
    case let .snapshot(.failed(action, error)):
      emit(.error, "SNAPSHOT", "single-shot failed", action: action, exit: "failure", error: error)
    case let .snapshot(.streamRegistered(id, action, emitInitial)):
      emit(.info, "SNAPSHOT", "stream registered (emitInitial=\(emitInitial))", id: id, action: action)
    case let .snapshot(.streamFrame(id, byteCount)):
      emit(.info, "SNAPSHOT", "stream frame (\(byteCount) B)", id: id)
    case let .snapshot(.streamEncodeFailed(id, error)):
      emit(.error, "SNAPSHOT", "stream frame encode failed", id: id, error: error)
    case let .snapshot(.streamFinished(id, reason)):
      emit(.info, "SNAPSHOT", "stream finished (\(reason))", id: id)

    // ── BACKPRESSURE DIAGNOSTIC (dev) ─────────────────────────────────────────────────
    case let .highFrequencyAction(id, count, window):
      emit(.error, "BACKPRESSURE", "high-frequency action: \(count)× within \(window.reduxFmt())", id: id)

    // ── STORE ─────────────────────────────────────────────────────────────────────────
    case let .store(message):
      emit(.info, "STORE", message)
  }
}


// MARK: - Sink

private let reduxLogger = Logger(subsystem: "com.gmsoft.TinyRedux.Example", category: "redux")

/// Formats one structured line (`[SOURCE] message · id=… · action=… · <duration> · exit=… ·
/// error=…`) and logs it at `level`. Mirrors main's metadata fields; `nil` fields are omitted.
@MainActor
private func emit(_ level: OSLogType,
                  _ source: String,
                  _ message: String,
                  id: String? = nil,
                  action: (any ReduxAction)? = nil,
                  duration: Duration? = nil,
                  exit: String? = nil,
                  error: (any Error)? = nil)
{
  var line = "[\(source)] \(message)"
  if let id       { line += " · id=\(id)" }
  if let action   { line += " · action=\(action)" }
  if let duration { line += " · \(duration.reduxFmt())" }
  if let exit     { line += " · exit=\(exit)" }
  if let error    { line += " · error=\(error)" }
  reduxLogger.log(level: level, "\(line, privacy: .public)")
}


// MARK: - Duration formatting (ported from main's `logRedux`)

private extension Duration
{
  func reduxFmt() -> String
  {
    let ms = UInt64(components.seconds * 1_000) +
             UInt64(components.attoseconds / 1_000_000_000_000_000)

    switch ms
    {
      case 0 ..< 5_000:       return "\(ms)ms"
      case 5_000 ..< 60_000:  return "\(ms / 1_000)s"
      case 60_000 ..< 3_600_000: return "\(ms / 60_000)m"
      default:
        let h = ms / 3_600_000
        let m = (ms / 60_000) % 60
        return m == 0 ? "\(h)h" : "\(h)h\(m)m"
    }
  }
}
