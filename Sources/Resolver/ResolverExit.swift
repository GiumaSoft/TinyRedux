//


import Foundation


/// ResolverExitTarget
///
/// The ways a resolver can LEAVE the resolver chain, grouped under
/// ``ResolverExit/exit(_:)``. Mirrors ``MiddlewareExitTarget`` but with `fail` instead
/// of `resolve` (the resolver IS the error branch — it can't route to itself).
public enum ResolverExitTarget<A: ReduxAction>: Sendable
{
  /// → REDUCER with the original (erroring) action — error considered recovered.
  case reduce

  /// → REDUCER with a DIFFERENT recovery action.
  case reduceAs(A)

  /// → ∅ terminate as FAILED (the error is final).
  case fail(SendableError)

  /// → ∅ terminate as success (error absorbed, no state change).
  case done
}


/// ResolverExit
///
/// Control-flow returned by a ``Resolver``'s `run`. `defaultNext` passes to the next
/// resolver ("not mine"); `exit(_:)` leaves the chain. Pruned vs `main`: no `.next`/
/// `.nextAs` (resolvers don't chain-transform). Only `<A>` — never touches `S`.
public enum ResolverExit<A: ReduxAction>: Sendable
{
  /// Pass to the next resolver ("not mine"). If none handles it → default → fail.
  case defaultNext

  /// Leave the chain → reduce / reduceAs / fail / done.
  case exit(ResolverExitTarget<A>)
}
