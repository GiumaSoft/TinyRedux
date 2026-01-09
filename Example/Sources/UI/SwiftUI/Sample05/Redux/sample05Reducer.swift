//


import Foundation
import TinyRedux


let sample05Reducer = AnyReducer<Sample05State, Sample05Action>(id: "sample05Reducer") { context in

  let (state, action) = context.args

  switch action {
  case .incXRotation:
    state.xRotation += .pi / 60
    return .next
  case .incYRotation:
    state.yRotation += .pi / 60
    return .next
  case .incZRotation:
    state.zRotation += .pi / 60
    return .next
  }
}
