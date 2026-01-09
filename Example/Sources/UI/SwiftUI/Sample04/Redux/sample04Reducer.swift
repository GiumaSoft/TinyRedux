//


import Foundation
import TinyRedux


let sample04Reducer = AnyReducer<Sample04State, Sample04Action>(id: "sample04Reducer") { context in
  
  let (state, action) = context.args
  
  switch action {
  default:
    
    return .defaultNext
  }
}
