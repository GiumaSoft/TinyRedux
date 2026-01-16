// swift-tools-version: 6.0


import Foundation


extension Store {
#if targetEnvironment(simulator)
  /// Allows simulator previews to mutate state directly without reducers, enabling rapid UI
  /// prototyping while keeping production behavior unchanged and avoiding dispatch overhead during
  /// design iterations and debugging sessions safely only. Allows previews to mutate state directly
  /// without reducers.
  public func previewState(_ update: (S) -> Void) {
    update(state)
  }
  #endif
}
