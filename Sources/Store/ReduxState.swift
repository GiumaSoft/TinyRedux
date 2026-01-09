// swift-tools-version: 6.2


import Observation
import SwiftUI


/// ReduxState
/// 
/// Mutable state observed by the UI; conformers expose a ``ReadOnly`` projection.
@MainActor
public protocol ReduxState: AnyObject,
                            Observable,
                            Sendable {

  /// The read-only projection type for this state.
  associatedtype ReadOnly: ReduxReadOnlyState where ReadOnly.State == Self

  /// A read-only view of the current state.
  var readOnly: ReadOnly { get }
}
