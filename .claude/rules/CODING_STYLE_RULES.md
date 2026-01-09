# Coding Style Rules

|              |                                           |
|--------------|-------------------------------------------|
| **Title**    | TinyRedux — Coding Style Rules            |
| **Status**   | Active                                    |
| **Category** | Standards Track                           |
| **Created**  | 2026-04-08                                |
| **Updated**  | 2026-04-08                                |

## Table of Contents

1. [Abstract](#1-abstract)
2. [Requirements Language](#2-requirements-language)
3. [Compliance](#3-compliance)
4. [SLD — Design Principles](#4-sld--design-principles)
5. [FLD — Folder Structure](#5-fld--folder-structure)
6. [DOC — Documentation](#6-doc--documentation)
7. [FMT — Formatting](#7-fmt--formatting)
8. [FNC — Functions](#8-fnc--functions)
9. [VIEW — Views (SwiftUI)](#9-view--views-swiftui)
10. [CNC — Concurrency](#10-cnc--concurrency)
11. [Appendix A — Rule Index](#11-appendix-a--rule-index)

---

## 1. Abstract

This document defines coding style rules for all Swift source files
in the TinyRedux project. Rules are grouped by category, each
identified by a stable prefix. Individual rules are identified by
`[PREFIX]-[NNN]` and MUST NOT be renumbered. New rules MUST be
appended at the end of their category with the next available number.

## 2. Requirements Language

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
"SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in
this document are to be interpreted as described in [RFC 2119][1].

[1]: https://datatracker.ietf.org/doc/html/rfc2119

## 3. Compliance

### 3.1. Before building

Every source file edit MUST comply with this document before
attempting any build (`xcodebuild`, `swift build`).

### 3.2. Pre-existing violations

If code already in the codebase violates these rules, the violation
MUST NOT be fixed silently. It MUST be reported to the developer in
a dedicated section of the plan (if in plan mode) or inline during
the conversation.

### 3.3. New files

After creating any new file, `./setup.sh` MUST be run before any
compile attempt.

---

## 4. SLD — Design Principles

### SLD-001 — Single Responsibility (SRP)

- **Level**: SHOULD
- **Statement**: There SHOULD never be more than one reason for a
  class to change. Every class SHOULD have only one responsibility.
- **Rationale**: Easier to understand, modify, and test. Changes to
  one responsibility don't affect unrelated parts of the system.

### SLD-002 — Open/Closed (OCP)

- **Level**: SHOULD
- **Statement**: Software entities SHOULD be open for extension, but
  closed for modification.
- **Rationale**: New features can be added without modifying existing
  code. Reduces the risk of introducing bugs.

### SLD-003 — Liskov Substitution (LSP)

- **Level**: SHOULD
- **Statement**: Functions that use pointers or references to base
  classes SHOULD be able to use pointers or references of derived
  classes without knowing it.
- **Rationale**: Enables polymorphic behavior. Replacing a superclass
  object with a subclass object MUST NOT break the program.

### SLD-004 — Interface Segregation (ISP)

- **Level**: SHOULD
- **Statement**: Clients SHOULD NOT be forced to depend upon
  interfaces that they do not use.
- **Rationale**: Reduces dependencies between classes, making the
  code more modular and maintainable.

### SLD-005 — Dependency Inversion (DIP)

- **Level**: SHOULD
- **Statement**: Modules SHOULD depend upon abstractions, not
  concretes.
- **Rationale**: Reduces dependencies between modules, making the
  code more flexible and easier to test.

---

## 5. FLD — Folder Structure

_Reserved for future rules._

---

## 6. DOC — Documentation

### DOC-001 — Root-level declarations

- **Level**: MUST
- **Statement**: Root-level functions and direct class/struct/enum
  declarations MUST have up to 2 lines of comments describing
  functionality using `///` prefix.

### DOC-002 — Nested functions

- **Level**: MAY
- **Statement**: Nested functions inside other functions MAY have a
  comment only if particularly complex, using `//` prefix.

---

## 7. FMT — Formatting

### FMT-001 — Parameter indentation (≤ 2 params)

- **Level**: MUST
- **Statement**: Functions with 2 or fewer parameters MUST keep the
  signature on a single line. Generic constraints MUST use a `where`
  clause after the return type, not inline syntax (see FMT-001
  non-compliant example).
- **Example**:

  ```swift
  func _foo(_ key: String, value: Any) -> some View {
    ...
  }

  func _bar<S>(_ value: S) -> some View where S: StringProtocol {
    ...
  }
  ```
- **Non-compliant**:
  ```swift
  // WRONG — inline generic constraint
  func _bar<S: StringProtocol>(_ value: S) -> some View {
    ...
  }
  ```

### FMT-002 — Parameter indentation (> 2 params)

- **Level**: MUST
- **Statement**: Functions with more than 2 parameters MUST break
  the signature with one parameter per line. The closing parenthesis
  MUST be aligned with the `func` keyword. Generic constraints MUST
  use a `where` clause on the line after the return type, not inline
  syntax.
- **Example**:
  ```swift
  func _foo<S, Content, Label>(
    _ title: S,
    content: () -> Content,
    icon: () -> Label
  ) -> some View where S: StringProtocol, Content: View, Label: View {
    ...
  }
  ```
- **Non-compliant**:
  ```swift
  // WRONG — inline generic constraints
  func _foo<S: StringProtocol, Content: View, Label: View>(
    _ title: S,
    content: () -> Content,
    icon: () -> Label
  ) -> some View {
    ...
  }
  ```

### FMT-003 — Return spacing

- **Level**: MUST
- **Statement**: If a line starts with `return`, the line immediately
  before it MUST be a blank line.

### FMT-004 — Switch case separator

- **Level**: MUST
- **Statement**: In `switch` statements, each `case` block MUST be
  preceded by a `///` comment line.
- **Example** (also demonstrates FMT-003):
  ```swift
  switch action {
  ///
  case .rotate(let dx, let dy):
    state.rotation = (qy * qx) * state.rotation

    return .next
  ///
  case .moveZ(let delta):
    state.zPosition += delta

    return .next
  }
  ```

### FMT-005 — @ViewBuilder indentation

- **Level**: MUST
- **Statement**: The `@ViewBuilder` attribute MUST be on its own
  line, immediately above the `var` or `func` declaration.
- **Example**:
  ```swift
  @ViewBuilder
  var _main_: some View {
    ...
  }

  @ViewBuilder
  func _foo() -> some View {
    ...
  }
  ```

### FMT-006 — K&R brace style

- **Level**: MUST
- **Statement**: Opening braces MUST be placed on the same line as
  the declaration (K&R / "One True Brace Style"). A single space
  MUST precede the opening brace. The closing brace MUST be on its
  own line, aligned with the start of the declaration.
- **Example**:
  ```swift
  /// Manages user session lifecycle.
  class SessionManager {
    ...
  }

  /// Returns the active user count.
  func activeCount() -> Int {
    ...
  }

  if condition {
    ...
  } else {
    ...
  }
  ```
- **Non-compliant**:
  ```swift
  // WRONG — Allman style
  func activeCount() -> Int
  {
    ...
  }
  ```

---

## 8. FNC — Functions

### FNC-001 — Decomposition

- **Level**: MUST
- **Statement**: Complex functions MUST be split into multiple
  smaller nested functions, with focus on reusable patterns, code
  readability, and single responsibility. Nested functions SHOULD
  use inline-closure syntax.
- **Example**:
  ```swift
  let reduce: (A) -> Void = { action in … }
  ```

---

## 9. VIEW — Views (SwiftUI)

### VW-001 — Component: cross-screen reusable

- **Level**: MUST
- **Statement**: A reusable component shared across screens MUST
  live in a dedicated file, typically organized into a
  `Components/` folder.

### VW-002 — Component: view-specific

- **Level**: MUST
- **Statement**: A component specific to a single view MUST live as
  a `@ViewBuilder` in a specialized file extension (e.g.
  `Sample+ViewBuilder`).

### VW-003 — Screen file structure

- **Level**: MUST
- **Statement**: A screen (root view attached to `WindowGroup`,
  navigation stack, or tab view) MUST be declared as 3 distinct
  files:

  - `Sample+View` — Root file of the view containing `body` and
    common properties.
  - `Sample+ViewBuilder` — Specialized components as `@ViewBuilder`
    computed properties, or as functions if input parameters are
    needed.
  - `Sample+ViewModel` — Decouples long property paths into a
    unique camelCase term, e.g.:
    `var isAuthenticated: Bool {`
    `store.user.credential.status.isAuthenticated }`

### VW-004 — @ViewBuilder naming: computed properties

- **Level**: MUST
- **Statement**: `@ViewBuilder` computed properties MUST use leading
  and trailing underscore naming.
- **Example**: `_main_`, `_header_`, `_content_`

### VW-005 — @ViewBuilder naming: functions

- **Level**: MUST
- **Statement**: `@ViewBuilder` functions MUST use leading underscore
  only.
- **Example**: `_row(for:)`, `_cell(at:)`

### VW-006 — `_main_` composition

- **Level**: MUST
- **Statement**: `_main_` is the root `@ViewBuilder` that defines
  the screen layout. It MUST only reference ViewBuilder computed
  properties (e.g. `_header_`, `_content_`), never ViewBuilder
  functions. Pure layout containers (`VStack`, `HStack`, `Spacer`)
  MAY appear directly in `_main_` with their parameters.
- **Example**:
  ```swift
  @ViewBuilder
  var _main_: some View {
    VStack(spacing: 16.0) {
      _disclaimer_
      _input_
      Spacer()
      _commands_
      LogsWindow()
    }
  }
  ```

---

## 10. CNC — Concurrency

### CNC-001 — nonisolated(unsafe) prohibition

- **Level**: MUST NOT
- **Statement**: `nonisolated(unsafe)` MUST NOT be used. Every
  nonisolated → MainActor boundary MUST use `nonisolated let`
  (safe, compiler-verified) on Sendable types.

### CNC-002 — MainActor.assumeIsolated prohibition

- **Level**: MUST NOT
- **Statement**: `MainActor.assumeIsolated` MUST NOT be used. If
  the compiler cannot prove isolation, the author MUST resolve it
  with the type system (typealias, attributes, refactoring), not
  runtime assertions.

---

## 11. Appendix A — Rule Index

| ID | Title | Level |
|----|-------|-------|
| SLD-001 | Single Responsibility (SRP) | SHOULD |
| SLD-002 | Open/Closed (OCP) | SHOULD |
| SLD-003 | Liskov Substitution (LSP) | SHOULD |
| SLD-004 | Interface Segregation (ISP) | SHOULD |
| SLD-005 | Dependency Inversion (DIP) | SHOULD |
| DOC-001 | Root-level declarations | MUST |
| DOC-002 | Nested functions | MAY |
| FMT-001 | Parameter indentation (≤ 2 params) | MUST |
| FMT-002 | Parameter indentation (> 2 params) | MUST |
| FMT-003 | Return spacing | MUST |
| FMT-004 | Switch case separator | MUST |
| FMT-005 | @ViewBuilder indentation | MUST |
| FMT-006 | K&R brace style | MUST |
| FNC-001 | Decomposition | MUST |
| VW-001 | Component: cross-screen reusable | MUST |
| VW-002 | Component: view-specific | MUST |
| VW-003 | Screen file structure | MUST |
| VW-004 | @ViewBuilder naming: computed properties | MUST |
| VW-005 | @ViewBuilder naming: functions | MUST |
| VW-006 | `_main_` composition | MUST |
| CNC-001 | nonisolated(unsafe) prohibition | MUST NOT |
| CNC-002 | MainActor.assumeIsolated prohibition | MUST NOT |
