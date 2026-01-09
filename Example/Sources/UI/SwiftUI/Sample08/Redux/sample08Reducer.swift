//


import Foundation
import TinyRedux


let sample08Reducer = AnyReducer<Sample08State, Sample08Action>(id: "sample08Reducer") { context in
  
  let (state, action) = context.args
  
  switch action {
  default:
    
    return .defaultNext
  }
}
