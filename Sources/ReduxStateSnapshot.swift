//


import Foundation


/// ReduxStateSnapshot
///
/// Immutable, transportable projection of a ``ReduxState`` captured at a pipeline
/// terminal. The Worker builds it on the main actor, JSON-encodes it to `Data`, and
/// hands it to the caller as a ``ReduxEncodedSnapshot``.
///
/// - `struct` by convention (value type, frozen at capture).
/// - `Codable`: the Worker encodes to `Data`; the caller decodes the same conformer.
/// - `Sendable`: travels inside the `Result` across isolation boundaries.
/// - `@MainActor init(state:)`: reads `@MainActor` properties of `S.ReadOnly`.
public protocol ReduxStateSnapshot<S>: Codable, Sendable
{
  associatedtype S: ReduxState

  @MainActor init(state: S.ReadOnly)
}
