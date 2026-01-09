//
//  Shared helpers for the worker-pipeline tests (resolver / effects / rate-control /
//  subscriptions). Fixtures (AppState/AppActions/mainReducer, DemoModule) live in
//  TestEnvironment.swift / SubStoreFixtures.swift.
//

import Foundation
@testable import TinyRedux


/// A Sendable error for middleware/effect failure tests.
enum TestError: Error, Sendable { case boom }


/// Spins the main-actor reduce loop until `predicate` holds or we give up.
@MainActor
func waitUntil(_ predicate: () -> Bool, max attempts: Int = 1_000) async
{
  var n = 0
  while !predicate(), n < attempts
  {
    await Task.yield()
    n += 1
  }
}


/// Main-actor recorder for assertions (capturable in `@Sendable` effect/resolver closures
/// since a `@MainActor` class is `Sendable`).
@MainActor
final class Box
{
  var value = 0
  var flag = false
  func bump() { value += 1 }
  func mark() { flag = true }
}
