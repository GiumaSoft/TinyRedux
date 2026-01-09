//


import Foundation
import TinyRedux


let sample03Reducer = AnyReducer<Sample03State, Sample03Action>(id: "sample03Reducer") { context in
  
  let (state, action) = context.args
  
  switch action {
  default:
    
    return .defaultNext
  }
}
