// swift-tools-version: 6.0


import Foundation

/// ReduxOrigin
///
/// Identifies where an error originated within the dispatch pipeline.
public enum ReduxOrigin: Equatable,
                         Sendable {

  case middleware(String)
}
