// CaseIDMacro.swift
// TinyReduxMacros

import SwiftSyntax
import SwiftSyntaxMacros

/// A member macro that generates a computed `id` property for an enum,
/// returning the case name as a `String` (ignoring associated values).
public struct CaseIDMacro: MemberMacro {

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            throw MacroDiagnostic.notAnEnum
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
                if element.parameterClause != nil {
                    return "case .\(name): return \"\(name)\""
                } else {
                    return "case .\(name): return \"\(name)\""
                }
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

enum MacroDiagnostic: Error, CustomStringConvertible {
    case notAnEnum

    var description: String {
        switch self {
        case .notAnEnum:
            return "@CaseID can only be applied to an enum"
        }
    }
}
