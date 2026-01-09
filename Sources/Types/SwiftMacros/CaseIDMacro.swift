// swift-tools-version: 6.2


import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros


public struct CaseIDMacro: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
      context.diagnose(.init(
        node: node,
        message: MacroDiagnostic(
          message: "@CaseID can only be applied to an enum",
          diagnosticID: .init(domain: "TinyReduxMacros", id: "notAnEnum"),
          severity: .error
        )
      ))
      return []
    }

    let caseNames = enumDecl.memberBlock.members.compactMap { member in
      member.decl.as(EnumCaseDeclSyntax.self)
    }.flatMap { caseDecl in
      caseDecl.elements.map(\.name.text)
    }

    guard !caseNames.isEmpty else { return [] }

    let switchCases = caseNames.map { name in
      "    case .\(name): \"\(name)\""
    }.joined(separator: "\n")

    let idProperty: DeclSyntax = """
      var id: String {
        switch self {
      \(raw: switchCases)
        }
      }
      """

    return [idProperty]
  }
}


private struct MacroDiagnostic: DiagnosticMessage {
  let message: String
  let diagnosticID: MessageID
  let severity: DiagnosticSeverity
}
