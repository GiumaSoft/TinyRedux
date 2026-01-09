//


import Foundation
import TinyRedux


let sample17Reducer = AnyReducer<Sample17State, Sample17Action>(id: "sample17Reducer") { context in
  
  let (state, action) = context.args
  
  switch action {
  default:
    
    return .defaultNext
  }
}
