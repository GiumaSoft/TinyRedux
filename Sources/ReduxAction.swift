//


import Foundation


/// ReduxAction
///
/// A dispatchable action — the single trigger for state changes. Model actions
/// as a flat `enum`, one case per intent. `id` (typically the case name)
/// identifies the action for logging; equality is intentionally **case-only**
/// (associated values are ignored), so an action's identity is its intent, not
/// its payload. Override `==` for payload-sensitive equality.
public protocol ReduxAction : CustomStringConvertible,
                              CustomDebugStringConvertible,
                              Identifiable,
                              Equatable,
                              Sendable
{
  /// A stable identifier — typically the enum case name.
  var id: String { get }
}


public extension ReduxAction {
  // CustomStringConvertible
  var description: String { id }
  // CustomDebugStringConvertible
  var debugDescription: String { id }
  // Equatable
  static func ==(lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}
