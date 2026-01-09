//


import Foundation
import TinyRedux


let sample09Reducer = AnyReducer<Sample09State, Sample09Action>(id: "sample09Reducer") { context in
  
  let (state, action) = context.args
  
  switch action {
  default:
    
    return .defaultNext
  }
}
