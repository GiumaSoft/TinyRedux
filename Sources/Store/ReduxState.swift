//


import Foundation
import Observation


/// ReduxState
///
/// Mutable application state observed by the UI. Conformers are `Observable`
/// reference types whose properties are mutated in place by ``Reducer``s.
/// SwiftUI picks up changes automatically through observation tracking.
///
/// Each conformer exposes a ``ReadOnly`` projection (``ReduxReadOnlyState``)
/// that is provided to ``Middleware``s and ``Resolver``s, ensuring only
/// reducers can write to state.
///
/// ## Rules
///
/// - `@MainActor`: state lives on the main actor; all mutations happen there.
/// - `Observable`: use `@Observable` macro for SwiftUI integration.
/// - `Sendable`: required because the ``Store`` crosses isolation boundaries.
/// - `readOnly`: the ``readOnly`` property must return a projection that
///   mirrors every observable property without exposing setters.
@MainActor
public protocol ReduxState: AnyObject,
                            Observable,
                            Sendable {
  
  /// The read-only projection type for this state.
  associatedtype ReadOnly: ReduxReadOnlyState where ReadOnly.State == Self
  
  /// A read-only view of the current state.
  var readOnly: ReadOnly { get }
}
