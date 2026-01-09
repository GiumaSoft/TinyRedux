//


import Foundation
import TinyRedux


let sample13Reducer = AnyReducer<Sample13State, Sample13Action>(id: "sample13Reducer") { context in
  
  let (state, action) = context.args
  
  switch action {
  default:
    
    return .defaultNext
  }
}
