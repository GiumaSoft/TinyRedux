//


import Foundation


/// Outcome carried by an `.exit` case in pipeline exit enums.
///
/// Replaces `Result<Void, SendableError>` for cleaner call-site syntax:
/// `.exit(.success)` instead of `.exit(.success(()))`.
@frozen
public enum ExitResult: Sendable {
  /// Action processed successfully, middleware interrupt pipeline then call reducer chain.
  case success
  /// Action completed with no further processing, middleware exit pipeline (no reducer chain is called).
  case done
  /// Unrecoverable error, middleware exit pipeline (no reducer chain is called).
  case failure(SendableError)
}
