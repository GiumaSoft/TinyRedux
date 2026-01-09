//


import Foundation


/// ResolverContext
///
/// What a ``Resolver`` receives: the live `state`, the `action` that errored, the
/// `error` to resolve, its `origin` (tracing), and `dispatch`. Like ``MiddlewareContext``
/// it carries the live `state` (read-only by convention) so the module lift can project
/// the local state via ``ReduxModuleMap/toState``. No `subscribe` (resolvers don't subscribe).
public struct ResolverContext<S, A>: Sendable
where S: ReduxState, A: ReduxAction
{
  /// The live state — read-only by convention (do NOT mutate from a resolver).
  public let state: S

  /// The action whose processing produced the error.
  public let action: A

  /// The error to resolve.
  public let error: SendableError

  /// Origin of the originating action (tracing/logging).
  public let origin: ReduxOrigin

  /// Publishes new actions (e.g. recovery side-effects).
  public let dispatch: @Sendable (A) -> Void

  init(_ state: S,
       action: A,
       error: SendableError,
       origin: ReduxOrigin,
       dispatch: @escaping @Sendable (A) -> Void)
  {
    self.state = state
    self.action = action
    self.error = error
    self.origin = origin
    self.dispatch = dispatch
  }
}
