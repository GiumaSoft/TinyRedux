import Observation
import XCTest
@testable import TinyRedux

@MainActor
@Observable
final class TestState: ReduxState, @unchecked Sendable {
    typealias ReadOnly = TestReadOnly

    var value: Int = 0
    var log: [String] = []

    var readOnly: TestReadOnly { TestReadOnly(self) }
}

@MainActor
final class TestReadOnly: ReadOnlyState, @unchecked Sendable {
    typealias State = TestState

    private let state: TestState

    init(_ state: TestState) {
        self.state = state
    }

    var value: Int { state.value }
    var log: [String] { state.log }
}

enum TestAction: Int, ReduxAction {
    case run = 1
    case inc = 2

    var id: Int { rawValue }
    var description: String { String(describing: self) }
    var debugDescription: String { description }
}

@MainActor
final class TinyReduxTests: XCTestCase {

    func testReducersRunInProvidedOrder() {
        let state = TestState()
        let reducerA = Reducer<TestState, TestAction>(id: "r1") { context in
            let (state, _) = context.args
            state.log.append("r1")
        }
        let reducerB = Reducer<TestState, TestAction>(id: "r2") { context in
            let (state, _) = context.args
            state.log.append("r2")
        }
        let store = Store.sharedInstance(
            override: true,
            initialState: state,
            middlewares: [],
            resolvers: [Resolver(id: "resolver") { context in
                XCTFail("Unexpected error in reducer order test: \(context.error)")
            }],
            reducers: [reducerA, reducerB]
        )

        store.dispatch(.run)

        XCTAssertEqual(state.log, ["r1", "r2"])
    }

    func testMiddlewareOrderIsPreserved() {
        let state = TestState()
        var calls: [String] = []
        let middlewareA = Middleware<TestState, TestAction>(id: "m1") { context in
            let (_, _, next, action) = context.args
            calls.append("m1.before")
            try next(action)
            calls.append("m1.after")
        }
        let middlewareB = Middleware<TestState, TestAction>(id: "m2") { context in
            let (_, _, next, action) = context.args
            calls.append("m2.before")
            try next(action)
            calls.append("m2.after")
        }
        let reducer = Reducer<TestState, TestAction>(id: "r") { _ in
            calls.append("reducer")
        }
        let store = Store.sharedInstance(
            override: true,
            initialState: state,
            middlewares: [middlewareA, middlewareB],
            resolvers: [Resolver(id: "resolver") { context in
                XCTFail("Unexpected error in middleware order test: \(context.error)")
            }],
            reducers: [reducer]
        )

        store.dispatch(.run)

        XCTAssertEqual(calls, ["m1.before", "m2.before", "reducer", "m2.after", "m1.after"])
    }

    func testMaxDispatchableDropsDuplicateBufferedActions() {
        let state = TestState()
        let reducer = Reducer<TestState, TestAction>(id: "inc") { context in
            let (state, _) = context.args
            state.value += 1
        }
        let store = Store.sharedInstance(
            override: true,
            initialState: state,
            middlewares: [],
            resolvers: [Resolver(id: "resolver") { context in
                XCTFail("Unexpected error in maxDispatchable test: \(context.error)")
            }],
            reducers: [reducer]
        )
        let action = TestAction.inc

        store.dispatch(maxDispatchable: 1, action, action, action)

        XCTAssertEqual(state.value, 1)
    }

    func testSharedInstanceReturnsSameStore() {
        let state = TestState()
        let reducer = Reducer<TestState, TestAction>(id: "noop") { _ in }
        let storeA = Store.sharedInstance(
            override: true,
            initialState: state,
            middlewares: [],
            resolvers: [Resolver(id: "resolver") { context in
                XCTFail("Unexpected error in shared instance test: \(context.error)")
            }],
            reducers: [reducer]
        )
        let storeB = Store.sharedInstance(
            initialState: state,
            middlewares: [],
            resolvers: [Resolver(id: "resolver") { context in
                XCTFail("Unexpected error in shared instance test: \(context.error)")
            }],
            reducers: [reducer]
        )

        XCTAssertTrue(storeA === storeB)
    }

    func testSharedInstanceOverridesWhenRequested() {
        let state = TestState()
        let reducer = Reducer<TestState, TestAction>(id: "noop") { _ in }
        let storeA = Store.sharedInstance(
            override: true,
            initialState: state,
            middlewares: [],
            resolvers: [Resolver(id: "resolver") { context in
                XCTFail("Unexpected error in shared instance override test: \(context.error)")
            }],
            reducers: [reducer]
        )
        let storeB = Store.sharedInstance(
            override: true,
            initialState: state,
            middlewares: [],
            resolvers: [Resolver(id: "resolver") { context in
                XCTFail("Unexpected error in shared instance override test: \(context.error)")
            }],
            reducers: [reducer]
        )

        XCTAssertFalse(storeA === storeB)
    }
}
