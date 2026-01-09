// ReduxAction.swift
// TinyRedux

import Foundation

/// ReduxAction
///
/// An identifiable, equatable action dispatched through a ``Store``.
public protocol ReduxAction: Identifiable,
                             Equatable,
                             Sendable {

    /// A stable identifier for logging and metrics.
    var id: String { get }
}

/// Attached member macro that synthesizes an `id` property from the enum case name.
@attached(member, names: named(id))
public macro CaseID() = #externalMacro(module: "TinyReduxMacros", type: "CaseIDMacro")
