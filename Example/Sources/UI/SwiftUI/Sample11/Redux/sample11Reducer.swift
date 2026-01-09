//


import Foundation
import TinyRedux


let sample11Reducer = AnyReducer<Sample11State, Sample11Action>(id: "sample11Reducer") { context in
  
  let (state, action) = context.args
  
  switch action {
  default:
    
    return .defaultNext
  }
}
