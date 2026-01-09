// Plugin.swift
// TinyReduxMacros

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct TinyReduxMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        CaseIDMacro.self,
    ]
}
