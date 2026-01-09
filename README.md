# TinyRedux

## Summary

**TinyRedux** is a small-footprint library, strongly inspired by ReduxJS, written in pure Swift.

## Overview

**TinyRedux** offers a significant improvement over traditional MVC and MVVM architectures.

`Store` centralizes global state management and removes the need to pass data across multiple ViewModels, which can become a heavy task when evolving consolidated logic.

**TinyRedux** adopts a **Supervised Redux Model** where middleware, resolver, and reducer cooperate in the same dispatch flow with distinct responsibilities:

- `Middleware` orchestrates async operations and side effects across the app. 

- `Resolver` supervises errors raised during that flow and applies remediation strategies before the action continues. 

- `Reducer` applies deterministic state transitions.

This separation keeps the architecture clean and aligns with `SOLID` principles thanks to composable abstractions for middleware, resolver, and store processing.

![TinyRedux flow diagram](https://github.com/GiumaSoft/TinyRedux/blob/main/ReduxFlow.gif)
