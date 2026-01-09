//


import Foundation
import TinyRedux


let sample02Reducer = AnyReducer<Sample02State, Sample02Action>(id: "sample02Reducer") { context in
  
  let (state, action) = context.args
  
  switch action {
  default:
    
    return .defaultNext
  }
}
