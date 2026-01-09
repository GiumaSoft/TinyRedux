//


import Foundation
import TinyRedux


let sample18Reducer = AnyReducer<Sample18State, Sample18Action>(id: "sample18Reducer") { context in
  
  let (state, action) = context.args
  
  switch action {
  default:
    
    return .defaultNext
  }
}
