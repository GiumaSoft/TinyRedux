// swift-tools-version: 6.0


import Foundation


/// ReduxAction
///
///
public protocol ReduxAction: CustomDebugStringConvertible,
                             CustomStringConvertible,
                             Equatable,
                             Identifiable,
                             Hashable,
                             Sendable {
  /// A stable identifier for the action.
  var id: Int { get }
}
