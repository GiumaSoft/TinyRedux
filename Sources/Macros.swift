//


@_exported import Observation


/// `@ReduxState` — for an OWNED, value-backed state (linear module or root).
/// Generates `ReadOnly`, `readOnly`, and the designated `init(<field>: T, …)`. The
/// stored `var`s stay stored and are the real observable storage. Declare `: ReduxState`
/// AND `@Observable` (AND `@MainActor`) explicitly — a macro cannot inject those onto
/// the class it is attached to.
@attached(member, names: named(ReadOnly), named(readOnly), named(init))
public macro ReduxState() = #externalMacro(module: "TinyReduxMacros", type: "ReduxStateMacro")


/// `@ReduxMappedState` — for a FLAT, app-independent module state projected onto a
/// root via `ReduxBinding` (`.scattered`). Generates `ReadOnly`, `readOnly`, the
/// designated `init(<field>: ReduxBinding<T>, …)`, turns each stored `var` into a
/// computed forwarder with a `_<field>` backing, and adds the `Observable` conformance.
/// Declare `: ReduxMappedState` and `@MainActor` (do NOT add `@Observable` — fields
/// become computed; `Observable` is a marker added by the macro).
@attached(member, names: named(ReadOnly), named(readOnly), named(init))
@attached(memberAttribute)
@attached(extension, conformances: Observable)
public macro ReduxMappedState() = #externalMacro(module: "TinyReduxMacros", type: "ReduxMappedStateMacro")


/// `@ReduxBindingBacked` — helper applied by `@ReduxMappedState` to each stored `var`
/// (computed forwarder over a `ReduxBinding` backing). Not used directly.
@attached(accessor)
@attached(peer, names: prefixed(_))
public macro ReduxBindingBacked() = #externalMacro(module: "TinyReduxMacros", type: "ReduxBindingBackedMacro")


/// `@ReduxAction` — for an action enum (`: ReduxAction`). Synthesizes `var id: String`
/// as a switch over the case names (`case .<name>: return "<name>"`), ignoring any
/// associated values. `description`/`debugDescription` come from the protocol extension.
@attached(member, names: named(id))
public macro ReduxAction() = #externalMacro(module: "TinyReduxMacros", type: "ReduxActionMacro")
