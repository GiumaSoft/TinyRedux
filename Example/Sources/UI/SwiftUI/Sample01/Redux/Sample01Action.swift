//


import Foundation
import TinyRedux


@ReduxAction
enum Sample01Action: ReduxAction {
  case addProduct(Product)
  case noop
  case removeProduct(Product)
  case removeProducts(IndexSet)
  case removeCartItem(CartItem)
  case removeCartItems([CartItem])

  @MainActor
  var debugString: String {
    switch self {
    ///
    case .addProduct(let p): "addProduct(\(p.name))"
    ///
    case .noop: "noop"
    ///
    case .removeProduct(let p): "removeProduct(\(p.name))"
    ///
    case .removeProducts(let indices): "removeProducts(\(indices))"
    ///
    case .removeCartItem(let r): "removeCartItem(\(r.index))"
    ///
    case .removeCartItems(let rs): "removeCartItems(\(rs.count))"
    }
  }
}
