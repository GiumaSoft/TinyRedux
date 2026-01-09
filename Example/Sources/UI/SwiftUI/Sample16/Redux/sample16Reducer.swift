//


import Foundation
import TinyRedux


let sample16Reducer = AnyReducer<Sample16State, Sample16Action>(id: "sample16Reducer") { context in
  
  let (state, action) = context.args
  
  switch action {
  default:
    
    return .defaultNext
  }
}
