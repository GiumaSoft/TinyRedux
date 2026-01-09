//


import Foundation
import TinyRedux


let sample01Reducer = AnyReducer<Sample01State, Sample01Action>(id: "sample01Reducer") { context in

  let (state, action) = context.args

  switch action {
  ///
  case .addProduct(let product):
    state.items.append(product)
    state.total += product.price
  ///
  case .removeCartItem(let removal):
    state.items.remove(at: removal.index)
    state.total -= removal.price
  ///
  case .removeCartItems(let removals):
    for removal in removals {
      state.items.remove(at: removal.index)
      state.total -= removal.price
    }
  ///
  default:

    return .defaultNext
  }

  return .next
}
