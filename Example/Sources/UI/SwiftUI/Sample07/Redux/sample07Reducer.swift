//


import Foundation
import TinyRedux


let sample07Reducer = AnyReducer<Sample07State, Sample07Action>(id: "sample07Reducer") { context in
  
  let (state, action) = context.args
  
  switch action {
  default:
    
    return .defaultNext
  }
}
