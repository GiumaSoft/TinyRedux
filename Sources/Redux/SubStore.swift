//


import Foundation
import SwiftUI


/// SubStore
///
@MainActor
@Observable
@dynamicMemberLookup public final class SubStore<LS, LA, GS, GA> where LS: Sendable, GS: Sendable, LA: Sendable & Equatable, GA: Sendable & Equatable {
  
  private let store: Store<GS, GA>
  
  @ObservationIgnored private let toLocalState: WritableKeyPath<GS, LS> & Sendable
  @ObservationIgnored private let toGlobalAction: @Sendable (LA) -> GA
  
  public nonisolated init(
    initialStore store: Store<GS, GA>,
    toLocalState: WritableKeyPath<GS, LS> & Sendable,
    toGlobalAction: @Sendable @escaping (LA) -> GA
  ) {
    self.store = store
    self.toLocalState = toLocalState
    self.toGlobalAction = toGlobalAction
  }
  
  public subscript<T>(dynamicMember keyPath: KeyPath<LS, T>) -> T {
    state[keyPath: keyPath]
  }
  
  public var state: LS {
    store.state[keyPath: toLocalState]
  }
  
  public nonisolated func dispatch(_ action: LA) {
    store.dispatch(toGlobalAction(action))
  }
}

extension SubStore {
  public func bind<T>(_ keyPath: KeyPath<LS, T>, _ action: @Sendable @escaping (T) -> LA) -> Binding<T> {
    Binding {
      self.state[keyPath: keyPath]
    } set: { newValue in
      self.dispatch(action(newValue))
    }
  }
}
