//

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics


/// A stored `var` projected by the state macros: its name and resolved type.
struct StoredVar
{
  let name: String
  let type: TypeSyntax
}


/// `"public "` if the annotated declaration is `public` (or `open`), else `""`.
/// Generated members must match the type's visibility — a `public` state type
/// conforming to the public `ReduxState`/`ReduxReadOnlyState` requires public witnesses,
/// and cross-module use (an external feature module) needs a public `init`/`readOnly`.
func publicPrefix(_ declaration: some DeclGroupSyntax) -> String
{
  let isPublic = declaration.modifiers.contains { modifier in
    modifier.name.tokenKind == .keyword(.public) || modifier.name.tokenKind == .keyword(.open)
  }
  return isPublic ? "public " : ""
}


/// Scans every stored `var` of a class (across all bindings of each declaration),
/// skipping computed and `@ObservationIgnored` properties. A binding whose type is
/// inferred from an initializer (invisible to a syntactic macro) is reported with a
/// diagnostic rather than dropped silently.
func scanStoredVars(_ classDecl: ClassDeclSyntax,
                    _ context: some MacroExpansionContext) -> [StoredVar]
{
  var result: [StoredVar] = []

  for member in classDecl.memberBlock.members
  {
    guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }
    guard varDecl.bindingSpecifier.tokenKind == .keyword(.var) else { continue }

    let hasObservationIgnored = varDecl.attributes.contains { attr in
      attr.as(AttributeSyntax.self)?.attributeName
        .as(IdentifierTypeSyntax.self)?.name.text == "ObservationIgnored"
    }
    guard !hasObservationIgnored else { continue }

    let bindings = Array(varDecl.bindings)
    for (index, binding) in bindings.enumerated()
    {
      guard binding.accessorBlock == nil else { continue }
      guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else { continue }

      let resolvedType: TypeSyntax?
      if let ownType = binding.typeAnnotation?.type
      {
        resolvedType = ownType
      }
      else if binding.initializer != nil
      {
        resolvedType = nil
      }
      else
      {
        resolvedType = bindings[(index + 1)...].lazy
          .compactMap { $0.typeAnnotation?.type }
          .first
      }

      guard let type = resolvedType else
      {
        context.diagnose(Diagnostic(
          node: binding,
          message: ReduxMacroMessage(
            "state macros require an explicit type annotation on stored 'var' properties; '\(name)' has an inferred type.",
            id: "missingTypeAnnotation"
          )
        ))
        continue
      }

      result.append(StoredVar(name: name, type: type))
    }
  }

  return result
}


/// Generic error for a macro applied to the wrong declaration kind.
struct ReduxMacroError: Error, CustomStringConvertible
{
  let description: String

  init(_ description: String)
  {
    self.description = description
  }
}


/// A diagnostic surfaced at a specific node during macro expansion.
struct ReduxMacroMessage: DiagnosticMessage
{
  let message: String
  let diagnosticID: MessageID
  let severity: DiagnosticSeverity

  init(_ message: String, id: String, severity: DiagnosticSeverity = .error)
  {
    self.message = message
    self.diagnosticID = MessageID(domain: "TinyReduxMacros", id: id)
    self.severity = severity
  }
}
