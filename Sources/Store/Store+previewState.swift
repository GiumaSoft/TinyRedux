// swift-tools-version: 6.2


extension Store {
  #if targetEnvironment(simulator)
  /// Mutates state directly without dispatching through the pipeline.
  ///
  /// Simulator-only. Use in SwiftUI previews to set up state without reducers or middlewares.
  ///
  /// - Parameter update: Closure that receives the mutable state.
  public func previewState(_ update: (State) -> Void) {
    update(state)
  }
  #endif
}
