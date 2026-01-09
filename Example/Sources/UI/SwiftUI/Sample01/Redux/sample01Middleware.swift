//


import Foundation
import TinyRedux


let sample01Middleware = AnyMiddleware<Sample01State, Sample01Action>(id: "sample01Middleware") { context in

  let (state, dispatch, action) = context.args

  switch action {
  ///
  case .removeProduct(let product):
    guard let index = state.items.firstIndex(where: { $0.name == product.name }) else {

      return .exit(.success)
    }

    return .nextAs(.removeCartItem(CartItem(index: index, price: product.price)))
  ///
  case .removeProducts(let indices):
    if indices.isEmpty { return .exit(.done) }
    let removals = indices.sorted().reversed().map { index in
      CartItem(index: index, price: state.items[index].price)
    }

    return .nextAs(.removeCartItems(removals))
  ///
  default:

    return .defaultNext
  }
}
