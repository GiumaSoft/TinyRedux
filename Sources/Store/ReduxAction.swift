//


import Foundation


/// ReduxAction
///
/// A dispatchable action that travels through the ``Store`` pipeline. Actions are
/// the single mechanism for triggering state changes and side effects. They cross
/// the `nonisolated` → `@MainActor` boundary via the ``Store/Worker/Dispatcher``
/// and are processed sequentially by middlewares, reducers, and — on error — resolvers.
///
/// ## Rules
///
/// - `Equatable`: enables deduplication and testing assertions.
/// - `Identifiable`: `id` groups actions for rate limiting and logging.
///   Use the ``ReduxAction()`` macro on enums to synthesize `id` from the case name.
/// - `Sendable`: required to cross isolation boundaries safely.
/// - `enum`: model actions as a flat `enum` — one case per intent.
public protocol ReduxAction: CustomStringConvertible,
                             CustomDebugStringConvertible,
                             Identifiable,
                             Equatable,
                             Sendable {

    /// A stable identifier for logging and metrics.
    var id: String { get }
}


/// Default implementations for `CustomStringConvertible`, `CustomDebugStringConvertible`, and `Equatable`.
/// Override in the enum body or an extension.
extension ReduxAction {
  ///
  public var description: String { id }
  ///
  public var debugDescription: String { id }
  ///
  public static func ==(lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

/// Attached macro that synthesizes `id` for an enum from its case names.
@attached(member, names: named(id))
public macro ReduxAction() = #externalMacro(module: "TinyReduxMacros", type: "ReduxActionMacro")
