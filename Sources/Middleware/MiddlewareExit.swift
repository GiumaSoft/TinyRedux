//


import Foundation


/// MiddlewareExitTarget
///
/// The ways a middleware (or a `.deferred` resume) can LEAVE the middleware chain,
/// grouped under ``MiddlewareExit/exit(_:)``. Named by destination — no `ExitResult`
/// conflation, no snapshot semantics here.
public enum MiddlewareExitTarget<A: ReduxAction>: Sendable
{
  /// → REDUCER with the current action (skips the remaining middlewares).
  case reduce

  /// → REDUCER with a DIFFERENT action.
  case reduceAs(A)

  /// → RESOLVER (explicit error routing, e.g. from a manual `do/try/catch`).
  case resolve(SendableError)

  /// → ∅ terminate the chain, NO reduce (success).
  case done
}


/// MiddlewareExit
///
/// Control-flow returned by a ``Middleware``'s `run`. `next`/`defaultNext`/`nextAs`
/// STAY in the chain; `exit(_:)` LEAVES it (→ reducer / resolver / ∅); `task`/`deferred`
/// are async effects. Errors normally travel via `throw` (→ resolver); `exit(.resolve)`
/// is the explicit, manually-caught variant. No `.fail` here — terminal failure lives
/// in the RESOLVER.
public enum MiddlewareExit<S, A>: Sendable
where S: ReduxState, A: ReduxAction
{
  /// Continue the chain with the SAME action (handled).
  case next

  /// Continue the chain with the same action, marked "not mine" (not logged).
  case defaultNext

  /// Continue the chain with a DIFFERENT action.
  case nextAs(A)

  /// Leave the chain → reduce / reduceAs / resolve / done.
  case exit(MiddlewareExitTarget<A>)

  /// Fire-and-forget async effect; the chain continues immediately.
  case task(TaskHandler<S>)

  /// Async effect that SUSPENDS the chain and resumes with a ``MiddlewareResumeExit``.
  case deferred(DeferredTaskHandler<S, A>)
}


/// MiddlewareResumeExit
///
/// Returned by a `.deferred` handler to RESUME the suspended chain. A subset of
/// ``MiddlewareExit`` (reuses ``MiddlewareExitTarget``) — no `task`/`deferred`
/// (no nested async), no `defaultNext`. Only `<A>`: it never touches `S`.
public enum MiddlewareResumeExit<A: ReduxAction>: Sendable
{
  /// Resume with the original action.
  case next

  /// Resume with a DIFFERENT action.
  case nextAs(A)

  /// Leave the chain → reduce / reduceAs / resolve / done.
  case exit(MiddlewareExitTarget<A>)
}
