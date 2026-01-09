// Store+Log.swift
// TinyRedux

import Foundation

extension Store {

    public enum Log: Sendable {
        case middleware(String, A, Duration, Result<Bool, any Error>)
        case reducer(String, A, Duration, Bool)
        case resolver(String, A, Duration, Bool, any Error)
        case store(String)
    }
}
