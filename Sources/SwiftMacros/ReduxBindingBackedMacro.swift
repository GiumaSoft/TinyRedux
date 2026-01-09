//

import SwiftSyntax
import SwiftSyntaxMacros


/// `@ReduxBindingBacked` — helper applied by `@ReduxMappedState` to each stored `var`.
/// Turns `var x: T` into a computed forwarder over a `ReduxBinding<T>` backing:
/// - `accessor`: `get { _x.value }` / `set { _x.value = newValue }`
/// - `peer`: `private let _x: ReduxBinding<T>`
public struct ReduxBindingBackedMacro {}


extension ReduxBindingBackedMacro: AccessorMacro
{
  public static func expansion(
    of node: AttributeSyntax,
    providingAccessorsOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [AccessorDeclSyntax]
  {
    guard let varDecl = declaration.as(VariableDeclSyntax.self),
          let binding = varDecl.bindings.first,
          let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
    else
    {
      return []
    }

    return [
      "get { _\(raw: name).value }",
      "set { _\(raw: name).value = newValue }"
    ]
  }
}


extension ReduxBindingBackedMacro: PeerMacro
{
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax]
  {
    guard let varDecl = declaration.as(VariableDeclSyntax.self),
          let binding = varDecl.bindings.first,
          let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
          let type = binding.typeAnnotation?.type
    else
    {
      return []
    }

    return ["private let _\(raw: name): ReduxBinding<\(type)>"]
  }
}
