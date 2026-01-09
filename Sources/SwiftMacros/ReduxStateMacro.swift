//

import SwiftSyntax
import SwiftSyntaxMacros


/// `@ReduxState` — generates the `ReadOnly` nested class, the `readOnly` lazy property,
/// and the designated `init`. The class must declare `: ReduxState` AND `@Observable`
/// explicitly (a macro cannot inject attributes/conformances onto the decl it is
/// attached to). For OWNED, value-backed (linear/root) states: the stored `var`s remain
/// stored and are the real `@Observable` source of truth.
///
/// Generated members are `public` when the annotated class is `public`/`open` (so a
/// `public` state type compiles its public-protocol conformance and can be used from
/// another module — e.g. an external feature framework).
public struct ReduxStateMacro: MemberMacro
{
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax]
  {
    guard let classDecl = declaration.as(ClassDeclSyntax.self) else
    {
      throw ReduxMacroError("@ReduxState can only be applied to a class")
    }

    let className = classDecl.name.text
    let acc = publicPrefix(classDecl)
    let storedVars = scanStoredVars(classDecl, context)

    let readOnlyProperties = storedVars.map { v in
      "    \(acc)var \(v.name): \(v.type) { state.\(v.name) }"
    }.joined(separator: "\n")

    let readOnlyClass: DeclSyntax = """
    @Observable
    @MainActor
    \(raw: acc)final class ReadOnly: ReduxReadOnlyState, Sendable {
        private unowned let state: \(raw: className)
        \(raw: acc)nonisolated init(_ state: \(raw: className)) { self.state = state }
    \(raw: readOnlyProperties)
    }
    """

    let readOnlyProperty: DeclSyntax = """
    @ObservationIgnored
    \(raw: acc)lazy var readOnly = ReadOnly(self)
    """

    let initParams = storedVars.map { "\($0.name): \($0.type)" }.joined(separator: ", ")
    let initAssignments = storedVars.map { "        self._\($0.name) = \($0.name)" }.joined(separator: "\n")

    let designatedInit: DeclSyntax = """
    \(raw: acc)nonisolated
    init(\(raw: initParams)) {
    \(raw: initAssignments)
    }
    """

    return [readOnlyClass, readOnlyProperty, designatedInit]
  }
}
