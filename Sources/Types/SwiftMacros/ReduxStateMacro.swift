//

import SwiftSyntax
import SwiftSyntaxMacros

/// A macro that generates the `ReadOnly` nested class and `readOnly` lazy property.
/// The class must declare `: ReduxState` conformance and `@Observable` explicitly.
public struct ReduxStateMacro: MemberMacro {

  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
      throw ReduxStateDiagnostic.notAClass
    }

    let className = classDecl.name.text

    let storedVars = classDecl.memberBlock.members.compactMap { member -> (String, TypeSyntax)? in
      guard let varDecl = member.decl.as(VariableDeclSyntax.self) else {
        return nil
      }

      let hasObservationIgnored = varDecl.attributes.contains { attr in
        attr.as(AttributeSyntax.self)?.attributeName
          .as(IdentifierTypeSyntax.self)?.name.text == "ObservationIgnored"
      }

      guard !hasObservationIgnored else {
        return nil
      }

      guard varDecl.bindingSpecifier.tokenKind == .keyword(.var) else {
        return nil
      }

      guard let binding = varDecl.bindings.first,
            let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
            let type = binding.typeAnnotation?.type,
            binding.accessorBlock == nil else {
        return nil
      }

      return (name, type)
    }

    let readOnlyProperties = storedVars.map { (name, type) in
      "    var \(name): \(type) { state.\(name) }"
    }.joined(separator: "\n")

    let readOnlyClass: DeclSyntax = """
    @Observable
    @MainActor
    final class ReadOnly: ReduxReadOnlyState {
        private unowned let state: \(raw: className)
        init(_ state: \(raw: className)) { self.state = state }
    \(raw: readOnlyProperties)
    }
    """

    let readOnlyProperty: DeclSyntax = """
    @ObservationIgnored
    lazy var readOnly = ReadOnly(self)
    """

    let initParams = storedVars.map { (name, type) in
      "\(name): \(type)"
    }.joined(separator: ", ")

    let initAssignments = storedVars.map { (name, _) in
      "        self._\(name) = \(name)"
    }.joined(separator: "\n")

    let designatedInit: DeclSyntax = """
    nonisolated
    init(\(raw: initParams)) {
    \(raw: initAssignments)
    }
    """

    return [readOnlyClass, readOnlyProperty, designatedInit]
  }
}

enum ReduxStateDiagnostic: Error, CustomStringConvertible {
  case notAClass

  var description: String {
    switch self {
    case .notAClass:
      return "@ReduxState can only be applied to a class"
    }
  }
}
