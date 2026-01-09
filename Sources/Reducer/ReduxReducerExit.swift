//


import Foundation


/// ReduxReducerExit
///
/// Exit signal returned by a reducer's `reduce` closure. It steers the reducer loop
/// (continue / stop) — the framework measures timing and logs automatically.
///
/// Unlike middleware/resolver (which skip logging their `.defaultNext`), the worker wraps
/// every `reduce` call in `measuring`, so a `.reducer` event is emitted for ALL exits —
/// including `.defaultNext` — whenever a log handler is attached.
public enum ReduxReducerExit: Sendable
{
  /// Action was handled — state was mutated. Continue with the remaining reducers.
  case next

  /// Action was handled — state was mutated, remaining reducers skipped.
  case done

  /// Pass-through — action was not relevant, no state change. Continue with the remaining
  /// reducers. Do NOT use for handled cases.
  case defaultNext
}
