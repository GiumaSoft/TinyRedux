// swift-tools-version: 6.0


import Foundation


/// `AnyMiddleware` is a protocol conform to Identifiable and Sendable, that represents a middleware
/// unit running on the MainActor. It receives a `MiddlewareContext`, can inspect the current action
/// and state, dispatch additional actions, run async work via the context helpers, and choose
/// whether to forward the action by calling next or stop the pipeline. This defines the standard
/// contract for composition, ordering, and coordination.
///
public protocol AnyMiddleware: Identifiable,
                               Sendable {
  /// The state type handled by this middleware.
  associatedtype S: ReduxState
  /// The action type handled by this middleware.
  associatedtype A: ReduxAction
  /// The stable identity of the entity associated with this instance.
  var id: String { get }
  /// Defines the middleware entry point invoked on the MainActor with a middleware context, where
  /// implementations can run side effects, dispatch actions, and optionally forward the pipeline to
  /// reducers or halt. Runs the middleware with the provided context.
  @MainActor
  func run(_ context: MiddlewareContext<S, A>) throws
}
