//


import Foundation
import TinyRedux


let sample21Reducer = AnyReducer<Sample21State, Sample21Action>(id: "sample21Reducer") { context in
  
  let (state, action) = context.args
  
  switch action {
  default:
    
    return .defaultNext
  }
}
