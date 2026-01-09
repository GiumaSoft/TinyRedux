//


import Foundation


/// Exit signal returned by a reducer's `reduce` closure.
///
/// Controls logging — the framework measures timing automatically.
@frozen
public enum ReducerExit: Sendable {

  /// Action was handled — state was mutated. Logged.
  case next

  /// Pass-through — action was not relevant, no state change. Not logged.
  /// do NOT use for handled cases.
  case defaultNext
}
