// swift-tools-version: 6.2


import SwiftUI


/// ReduxAction
///
/// An identifiable, equatable, hashable action dispatched through a ``Store``.
public protocol ReduxAction: CustomDebugStringConvertible,
                             CustomStringConvertible,
                             Equatable,
                             Identifiable,
                             Sendable {
  /// A stable identifier for logging and metrics.
  var id: String { get }
}


@attached(member, names: named(id))
public macro CaseID() = #externalMacro(module: "TinyReduxMacros", type: "CaseIDMacro")
