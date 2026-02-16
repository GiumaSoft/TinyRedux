// swift-tools-version: 6.0


import Foundation

///
///
///
public enum ResolverOutcome<A>: Sendable where A: ReduxAction {
  // dispatch(new action)
  case retry(A)
  // reduce(new action)
  case reduce(A)
  // try next resolver in chain
  case next
  // stop resolver chain immediately with unresolved failure
  case fail
}
