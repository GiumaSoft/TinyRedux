//

import SwiftCompilerPlugin
import SwiftSyntaxMacros


@main
struct TinyReduxMacroPlugin: CompilerPlugin
{
  let providingMacros: [Macro.Type] = [
    ReduxStateMacro.self,
    ReduxMappedStateMacro.self,
    ReduxBindingBackedMacro.self,
    ReduxActionMacro.self
  ]
}
