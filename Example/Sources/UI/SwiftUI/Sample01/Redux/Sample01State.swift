//


import Foundation
import Observation
import TinyRedux


/// A product available for purchase.
/// Identified by name, with a unit price.
struct Product: Equatable, Sendable, Identifiable {
  let id = UUID()
  let name: String
  let price: Decimal
}

/// A cart removal operation with pre-resolved index and price.
struct CartItem: Equatable, Sendable {
  let index: Int
  let price: Decimal
}

extension Product {
  static let catalog: [Product] = [
    Product(name: "Bread", price: 1.20),
    Product(name: "Milk", price: 1.50),
    Product(name: "Eggs", price: 2.80),
    Product(name: "Pasta", price: 0.90),
    Product(name: "Apples", price: 3.00),
  ]
}


@ReduxState
@Observable
final class Sample01State: ReduxState {
  var items: Array<Product>
  var total: Decimal
}
