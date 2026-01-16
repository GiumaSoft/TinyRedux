// swift-tools-version: 6.0


import Foundation


/// Identifies where a Redux error originated.
///
///
public enum ReduxErrorOrigin: Sendable, Equatable {
  /// Error thrown by a middleware.
  case middleware(String)
}
