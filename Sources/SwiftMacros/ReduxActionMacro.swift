//

import SwiftSyntax
import SwiftSyntaxMacros


/// `@ReduxAction` — synthesizes `var id: String` for an action enum as a switch over
/// the case names (`case .<name>: return "<name>"`). Associated values are ignored,
/// matching the protocol's case-only identity. Throws if applied to a non-enum.
public struct ReduxActionMacro: MemberMacro
{
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax]
  {
    guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
      throw ReduxMacroError("@ReduxAction can only be applied to an enum")
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
