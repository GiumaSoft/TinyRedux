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
///   Use the ``CaseID()`` macro on enums to synthesize `id` from the case name.
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

/// Attached member macro that synthesizes an `id` property from the enum case name.
@attached(member, names: named(id))
public macro CaseID() = #externalMacro(module: "TinyReduxMacros", type: "CaseIDMacro")
