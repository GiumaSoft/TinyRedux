# TinyRedux

## Summary

TinyRedux is small footprint library strongly inspired to ReduxJS written in pure Swift.

## Overview

TinyRedux offer to the developers a significant improvment over MVC and MVVM architectural pattern. 

In fact with TinyRedux global state management, you don't need anymore pass data across whole app ViewModels which become a really heavy task when you update the logic of something has already been consolidated. 

With Store you can easely access to the entire app state or you can cherry pick all states are needed in your local View context with SubStore. 

Middlewares are the resolver for all async operations across the app while Reducers are the only deputed object that can change the state of the app. 

Finally the Dispatch is the function that let you operate actions in this Redux-like framework.


![Alt Text](https://github.com/GiumaSoft/TinyRedux/blob/main/ReduxFlow.gif)
