//

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics

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

    // Scan every stored `var`, across ALL bindings of each declaration, so
    // `var a, b: Int` contributes both `a` and `b`. A binding without its own
    // type annotation inherits the trailing annotation of a later binding in the
    // same declaration (Swift's `var a, b: Int` rule). A stored `var` whose type
    // cannot be resolved syntactically — inferred from an initializer, e.g.
    // `var n = 0` — is reported with a diagnostic instead of being dropped silently.
    var storedVars: [(name: String, type: TypeSyntax)] = []

    for member in classDecl.memberBlock.members {
      guard let varDecl = member.decl.as(VariableDeclSyntax.self) else {
        continue
      }
      guard varDecl.bindingSpecifier.tokenKind == .keyword(.var) else {
        continue
      }
      let hasObservationIgnored = varDecl.attributes.contains { attr in
        attr.as(AttributeSyntax.self)?.attributeName
          .as(IdentifierTypeSyntax.self)?.name.text == "ObservationIgnored"
      }
      guard !hasObservationIgnored else {
        continue
      }

      let bindings = Array(varDecl.bindings)
      for (index, binding) in bindings.enumerated() {
        // Computed properties are not stored state — skip.
        guard binding.accessorBlock == nil else {
          continue
        }
        // Only simple identifier patterns are projected.
        guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
          continue
        }

        let resolvedType: TypeSyntax?
        if let ownType = binding.typeAnnotation?.type {
          resolvedType = ownType
        } else if binding.initializer != nil {
          // Type inferred from the initializer — invisible to a syntactic macro.
          resolvedType = nil
        } else {
          // `var a, b: Int`: an un-annotated binding inherits the trailing
          // annotation of a later binding in the same declaration.
          resolvedType = bindings[(index + 1)...].lazy
            .compactMap { $0.typeAnnotation?.type }
            .first
        }

        guard let type = resolvedType else {
          context.diagnose(Diagnostic(
            node: binding,
            message: ReduxStateMacroMessage(
              "@ReduxState requires an explicit type annotation on stored 'var' properties; '\(name)' has an inferred type.",
              id: "missingTypeAnnotation"
            )
          ))

          continue
        }

        storedVars.append((name, type))
      }
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

/// Diagnostic surfaced at a specific binding — e.g. a stored `var` with an
/// inferred type that `@ReduxState` cannot project without an explicit annotation.
struct ReduxStateMacroMessage: DiagnosticMessage {

  let message: String
  let diagnosticID: MessageID
  let severity: DiagnosticSeverity

  init(_ message: String, id: String, severity: DiagnosticSeverity = .error) {
    self.message = message
    self.diagnosticID = MessageID(domain: "TinyReduxMacros", id: id)
    self.severity = severity
  }
}
