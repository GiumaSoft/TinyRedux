//


import Combine
import Foundation
import SwiftUI


/// Type that stores the state of the app or module allowing feeding actions.
@Observable @dynamicMemberLookup public final class SubStore<LS, LA, GS, GA> where LS: Sendable, GS: Sendable, LA: Equatable, GA: Equatable {
  private let store: Store<GS, GA>
  @ObservationIgnored private let toLocalState: WritableKeyPath<GS, LS>
  @ObservationIgnored private let toGlobalAction: (LA) -> GA
  
  public init(
    initialStore store: Store<GS, GA>,
    toLocalState: WritableKeyPath<GS, LS>,
    toGlobalAction: @escaping (LA) -> GA
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
  
  public func dispatch(_ action: LA) {
    store.dispatch(toGlobalAction(action))
  }
}

extension SubStore {
  public func bind<T>(_ keyPath: KeyPath<LS, T>, _ action: @escaping (T) -> LA) -> Binding<T> {
    Binding {
      self.state[keyPath: keyPath]
    } set: { newValue in
      self.dispatch(action(newValue))
    }
  }
}
