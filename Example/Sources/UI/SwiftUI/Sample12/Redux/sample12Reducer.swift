//


import Foundation
import TinyRedux


let sample12Reducer = AnyReducer<Sample12State, Sample12Action>(id: "sample12Reducer") { context in
  
  let (state, action) = context.args
  
  switch action {
  default:
    
    return .defaultNext
  }
}
