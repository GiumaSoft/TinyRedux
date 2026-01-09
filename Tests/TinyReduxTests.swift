//

import Foundation
import Observation
import Synchronization
import Testing
@testable import TinyRedux


@MainActor
@Observable
final class TestState: ReduxState, @unchecked Sendable {
  typealias ReadOnly = TestReadOnly

  var value: Int = 0
  var log: [String] = []

  var readOnly: TestReadOnly { TestReadOnly(self) }
}

@MainActor
@Observable
final class TestReadOnly: ReduxReadOnlyState, @unchecked Sendable {
  typealias State = TestState

  let state: TestState

  init(_ state: TestState) {
    self.state = state
  }

  var value: Int { state.value }
  var log: [String] { state.log }
}

@ReduxAction
enum TestAction: ReduxAction {
  case run
  case inc
}

enum TestError: Error {
  case test
  case manual
}

struct TestSnapshot: ReduxStateSnapshot {
  typealias S = TestState
  let value: Int
  let log: [String]

  @MainActor
  init(state: TestReadOnly) {
    self.value = state.value
    self.log = state.log
  }
}


extension Store where S == TestState {
  func dispatchAndDecode(_ action: A) async -> TestSnapshot {
    let result = await dispatch(action, snapshot: TestSnapshot.self)
    let data = try! result.get()

    return try! JSONDecoder().decode(TestSnapshot.self, from: data)
  }
}


@Suite(.serialized)
@MainActor
struct TinyReduxTests {

  static func poll(
    timeout: Int = 500,
    interval: UInt64 = 2_000_000,
    while condition: @MainActor () -> Bool
  ) async {
    for _ in 0..<timeout where condition() {
      try? await Task.sleep(nanoseconds: interval)
    }
  }
}
