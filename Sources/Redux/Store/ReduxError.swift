// swift-tools-version: 6.0


import Foundation


/// Redux error.
///
///
public enum ReduxError: Error, Sendable {
  case storeDropActionByQueueLimit(limit: UInt)
  case storeDropActionByUnresolvedError(any Error)
}
