// swift-tools-version: 6.0


import Foundation


/// A reducer that mutates state in response to actions. Reducers run on the MainActor and receive a
/// ReducerContext carrying mutable state and the triggering action. Keep logic synchronous and
/// deterministic, focusing on state transitions, while deferring side effects to middleware. The
/// reducer stores its handler closure for later execution during dispatch processing. Multiple
/// reducers can be composed in order, each receiving the same action and state reference. Use
/// identifiers for logging and performance metrics, and keep reducer bodies small for testability
/// and clarity across features in larger applications and modules.
@frozen public struct Reducer<S, A>: Sendable where S : ReduxState, A : ReduxAction {
  /// A stable identifier for logging and metrics.
  public let id: String
  /// Stored reduction closure executed to mutate state on the MainActor.
  internal let reduce: @MainActor (ReducerContext<S, A>) -> Void
  /// Creates a reducer with an identifier and reduction closure, storing it for later execution on
  /// the MainActor when actions reach the reducer phase during dispatch processing for each action
  /// instance. Creates a reducer with the given identifier and body.
  /// - Parameters:
  ///   - id: Identifier for logging and metrics.
  ///   - reduce: The reducer body that mutates state.
  public init(id: String, _ reduce: @escaping @MainActor (ReducerContext<S, A>) -> Void) {
    self.id = id
    self.reduce = reduce
  }
}
