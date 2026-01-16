// swift-tools-version: 6.0


import Foundation


/// AnyResolver protocol.
///
///
public protocol AnyResolver: Identifiable, Sendable {
  /// The state type handled by this resolver.
  associatedtype S: ReduxState
  /// The action type handled by this resolver.
  associatedtype A: ReduxAction
  /// The stable identity of the entity associated with this instance.
  var id: String { get }
  /// Defines the resolver entry point invoked on the MainActor with a resolver context, where
  /// implementations inspect errors, optionally dispatch actions, and forward to the next resolver
  /// in the chain safely. Runs the resolver with the provided context.
  @MainActor
  func run(_ context: ResolverContext<S, A>)
}
