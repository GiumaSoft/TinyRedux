// swift-tools-version: 6.2


import SwiftCompilerPlugin
import SwiftSyntaxMacros


@main
struct TinyReduxMacroPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    CaseIDMacro.self
  ]
}
