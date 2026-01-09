//


import Foundation


/// Carries the continuation and snapshot closure for a `dispatch(_:snapshot:)` call.
///
/// Created by the Store dispatch method; travels through the AsyncStream inside
/// `TaggedActionEvent`. The Worker loop uses it to resume the caller's continuation
/// at the pipeline terminal point.
internal struct ReadOnlySnapshot<S: ReduxState>: Sendable {
  let continuation: CheckedContinuation<Result<Data, Error>, Never>
  let snapshot: @MainActor @Sendable (S.ReadOnly) throws -> Data
}
