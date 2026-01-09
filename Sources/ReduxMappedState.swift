//


import Foundation


/// ReduxMappedState
///
/// Marker for a module state that is PROJECTED field-by-field (via ``ReduxBinding``)
/// onto split, app-owned sub-states of the root, instead of owning its storage
/// (`.scattered` composition). It refines ``ReduxState`` — so store/worker/reducer
/// treat it uniformly. A `@ReduxMappedState` class writes this conformance INLINE
/// (`final class X: ReduxMappedState`); the macro adds only the `Observable` marker
/// conformance (an inline state conformance breaks the `ReadOnly`↔`State` inference
/// cycle). Observability rides the binding target (the live root `@Observable` leaves
/// in-app; an internal ``ReduxBindingValue`` in tests).
public protocol ReduxMappedState: ReduxState {}
