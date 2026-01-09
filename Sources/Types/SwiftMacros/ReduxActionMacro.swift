//

import SwiftSyntax
import SwiftSyntaxMacros

/// A macro that synthesizes `id` for an enum from its case names.
public struct ReduxActionMacro: MemberMacro {

  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
      throw ReduxActionDiagnostic.notAnEnum
    }

    let cases = enumDecl.memberBlock.members.compactMap {
      $0.decl.as(EnumCaseDeclSyntax.self)
    }

    guard !cases.isEmpty else {
      return []
    }

    let switchCases = cases.flatMap { caseDecl in
      caseDecl.elements.map { element in
        let name = element.name.text

        return "case .\(name): return \"\(name)\""
      }
    }

    let body = switchCases.joined(separator: "\n        ")

    let idProperty: DeclSyntax = """
    public var id: String {
        switch self {
        \(raw: body)
        }
    }
    """

    return [idProperty]
  }
}

enum ReduxActionDiagnostic: Error, CustomStringConvertible {
  case notAnEnum

  var description: String {
    switch self {
    case .notAnEnum:
      return "@ReduxAction can only be applied to an enum"
    }
  }
}
