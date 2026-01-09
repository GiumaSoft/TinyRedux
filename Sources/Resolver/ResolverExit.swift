//


import Foundation


/// Exit signal returned by a resolver's `run()` method.
///
/// Controls how the resolve chain proceeds after error handling.
@frozen
public enum ResolverExit<A: ReduxAction>: Sendable {

  /// Error handled, log and forward to the next resolver.
  case next

  /// Error not handled, forward to next resolver.
  case defaultNext

  /// Error handled, log and forward modified action to next resolver.
  case nextAs(SendableError, A)

  /// Error recovered, log and forward to reduce chain.
  case reduce

  /// Error recovered, log and forward modified action to reduce chain.
  case reduceAs(A)

  /// Error handled (`.success`) or unrecoverable (`.failure`), log and terminate pipeline.
  case exit(Result<Void, SendableError>)
}
