//


import Foundation


/// Outcome carried by an `.exit` case in pipeline exit enums.
///
/// Replaces `Result<Void, SendableError>` for cleaner call-site syntax:
/// `.exit(.success)` instead of `.exit(.success(()))`.
@frozen
public enum ExitResult: Sendable {
  case success
  case done
  case failure(SendableError)
}
