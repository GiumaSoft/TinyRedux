//


import Foundation
import TinyRedux


let sample14Reducer = AnyReducer<Sample14State, Sample14Action>(id: "sample14Reducer") { context in
  
  let (state, action) = context.args
  
  switch action {
  default:
    
    return .defaultNext
  }
}
