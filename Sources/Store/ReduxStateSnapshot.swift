//


import Foundation


/// Immutable projection of a ReduxState at a pipeline terminal point.
///
/// Conformers capture a frozen slice of `S.ReadOnly` at the moment the pipeline
/// terminates. The Worker encodes the conformer to JSON (`Data`) and delivers it
/// to the caller via `Result<Data, Error>`.
///
/// - Value type by convention (struct).
/// - `Codable`: Worker encodes to `Data`, caller decodes the same type.
/// - `Sendable`: travels in the `Result` across isolation boundaries.
/// - `@MainActor init(state:)`: conformer accesses `@MainActor` properties of `S.ReadOnly`.
public protocol ReduxStateSnapshot<S>: Codable,
                                       Sendable {
  ///
  associatedtype S: ReduxState
  
  ///
  @MainActor init(state: S.ReadOnly)
}
