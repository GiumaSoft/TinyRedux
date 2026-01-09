//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct TinyReduxMacroPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    ReduxActionMacro.self,
    ReduxStateMacro.self,
  ]
}
