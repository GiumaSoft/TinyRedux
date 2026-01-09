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
///
/// ## Logging
///
/// `description` (nonisolated) is the stable, isolation-free representation —
/// typically the case name; safe to print from anywhere.
/// `debugString` (`@MainActor`) is the richer, isolation-aware representation
/// used by the pipeline log; it can read associated values that hold MainActor
/// state (e.g. `@Observable` reference types).
public protocol ReduxAction: CustomStringConvertible,
                             Identifiable,
                             Equatable,
                             Sendable {

  /// A stable identifier for logging and metrics.
  var id: String { get }

  /// Rich, MainActor-isolated string used by the pipeline log handler.
  /// Defaults to ``description``; override (or let the ``ReduxAction()`` macro
  /// synthesize it) to expose associated values.
  @MainActor
  var debugString: String { get }
}


/// Default implementations for `CustomStringConvertible`, `debugString`, and `Equatable`.
/// Override in the enum body or an extension.
extension ReduxAction {
  ///
  public var description: String { id }
  ///
  @MainActor
  public var debugString: String { description }
  ///
  public static func ==(lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

/// Attached macro that synthesizes `id` for an enum from its case names.
/// `debugString` defaults to ``description`` via the protocol extension; override
/// in a `@MainActor` extension to expose associated values for richer logging.
@attached(member, names: named(id))
public macro ReduxAction() = #externalMacro(module: "TinyReduxMacros", type: "ReduxActionMacro")
