//


import Foundation
import TinyRedux


let sample06Reducer = AnyReducer<Sample06State, Sample06Action>(id: "sample06Reducer") { context in
  
  let (state, action) = context.args
  
  switch action {
  default:
    
    return .defaultNext
  }
}
