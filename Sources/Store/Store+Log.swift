// Store+Log.swift
// TinyRedux

import Foundation

extension Store {

    public enum Log {
        case middleware(String, Action, Duration, Result<Bool, any Error>)
        case reducer(String, Action, Duration, Bool)
        case resolver(String, Action, Duration, Bool, any Error)
        case store(String)
    }
}
