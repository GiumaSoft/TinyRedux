//

import SwiftSyntax
import SwiftSyntaxMacros


/// `@ReduxMappedState` — for a FLAT, app-independent module state whose stored `var`s
/// are projected onto a root via `ReduxBinding` (`.scattered` composition).
///
/// Roles:
/// - `member`: generates `ReadOnly`, `readOnly`, and the designated
///   `init(<field>: ReduxBinding<T>, …)`.
/// - `memberAttribute`: attaches `@ReduxBindingBacked` to every stored `var`
///   (which turns it into a computed forwarder + adds the `_<field>` backing).
/// - `extension`: adds the `ReduxMappedState` conformance.
///
/// The class must NOT also be `@Observable` (its fields become computed, so an
/// `@Observable` accessor would collide). Conformance to `Observable` is free —
/// it is an empty marker reached via `ReduxMappedState: ReduxState`.
public struct ReduxMappedStateMacro {}


extension ReduxMappedStateMacro: MemberMacro
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
      throw ReduxMacroError("@ReduxMappedState can only be applied to a class")
    }

    let className = classDecl.name.text
    let acc = publicPrefix(classDecl)
    let storedVars = scanStoredVars(classDecl, context)

    let readOnlyProperties = storedVars.map { v in
      "    \(acc)var \(v.name): \(v.type) { state.\(v.name) }"
    }.joined(separator: "\n")

    let readOnlyClass: DeclSyntax = """
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

    let initParams = storedVars.map { "\($0.name): ReduxBinding<\($0.type)>" }.joined(separator: ", ")
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


extension ReduxMappedStateMacro: MemberAttributeMacro
{
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingAttributesFor member: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [AttributeSyntax]
  {
    guard let varDecl = member.as(VariableDeclSyntax.self) else { return [] }
    guard varDecl.bindingSpecifier.tokenKind == .keyword(.var) else { return [] }

    let hasObservationIgnored = varDecl.attributes.contains { attr in
      attr.as(AttributeSyntax.self)?.attributeName
        .as(IdentifierTypeSyntax.self)?.name.text == "ObservationIgnored"
    }
    guard !hasObservationIgnored else { return [] }

    // Only stored vars (no accessor block) get backed.
    let isStored = varDecl.bindings.allSatisfy { $0.accessorBlock == nil }
    guard isStored else { return [] }

    return ["@ReduxBindingBacked"]
  }
}


extension ReduxMappedStateMacro: ExtensionMacro
{
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax]
  {
    // `protocols` holds the `Observable` marker conformance unless already stated.
    // (`ReduxMappedState` itself is written inline by the author, like `: ReduxState`
    // for `@ReduxState` — an inline conformance breaks the ReadOnly↔State cycle.)
    guard !protocols.isEmpty else { return [] }

    let conformances = protocols.map { $0.trimmedDescription }.joined(separator: ", ")
    let ext = try ExtensionDeclSyntax("extension \(type.trimmed): \(raw: conformances) {}")
    return [ext]
  }
}
