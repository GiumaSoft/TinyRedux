//


import Foundation


/// ReduxMiddlewareExitTarget
///
/// The ways a middleware (or a `.deferred` resume) can LEAVE the middleware chain,
/// grouped under ``ReduxMiddlewareExit/exit(_:)``. Named by destination — no `ExitResult`
/// conflation, no snapshot semantics here.
public enum ReduxMiddlewareExitTarget<A: ReduxAction>: Sendable
{
  /// → REDUCER with the current action (skips the remaining middlewares).
  case reduce

  /// → REDUCER with a DIFFERENT action.
  case reduceAs(A)

  /// → RESOLVER (explicit error routing, e.g. from a manual `do/try/catch`).
  case resolve(ReduxSendableError)

  /// → ∅ terminate the chain, NO reduce (success).
  case done
}


/// ReduxMiddlewareExit
///
/// Control-flow returned by a ``ReduxMiddleware``'s `run`. `next`/`defaultNext`/`nextAs`
/// STAY in the chain; `exit(_:)` LEAVES it (→ reducer / resolver / ∅); `task`/`deferred`
/// are async effects. Errors normally travel via `throw` (→ resolver); `exit(.resolve)`
/// is the explicit, manually-caught variant. No `.fail` here — terminal failure lives
/// in the RESOLVER.
public enum ReduxMiddlewareExit<S, A>: Sendable
where S: ReduxState, A: ReduxAction
{
  /// Continue the chain with the SAME action (handled).
  case next

  /// Continue the chain with the same action, marked "not mine" (not logged).
  case defaultNext

  /// Continue the chain with a DIFFERENT action.
  case nextAs(A)

  /// Leave the chain → reduce / reduceAs / resolve / done.
  case exit(ReduxMiddlewareExitTarget<A>)

  /// Fire-and-forget async effect; the chain continues immediately.
  case task(ReduxTaskHandler<S>)

  /// Async effect that SUSPENDS the chain and resumes with a ``ReduxMiddlewareResumeExit``.
  case deferred(ReduxDeferredTaskHandler<S, A>)
}


/// ReduxMiddlewareResumeExit
///
/// Returned by a `.deferred` handler to RESUME the suspended chain. A subset of
/// ``ReduxMiddlewareExit`` (reuses ``ReduxMiddlewareExitTarget``) — no `task`/`deferred`
/// (no nested async), no `defaultNext`. Only `<A>`: it never touches `S`.
public enum ReduxMiddlewareResumeExit<A: ReduxAction>: Sendable
{
  /// Resume with the original action.
  case next

  /// Resume with a DIFFERENT action.
  case nextAs(A)

  /// Leave the chain → reduce / reduceAs / resolve / done.
  case exit(ReduxMiddlewareExitTarget<A>)
}
