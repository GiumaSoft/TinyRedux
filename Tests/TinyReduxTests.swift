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
    func testReduxErrorDescriptionUsesTypeNames() {
        let error = ReduxError.storeDeallocated(TestState.self, TestAction.self)
        let stateName = String(describing: TestState.self)
        let actionName = String(describing: TestAction.self)
        let expected = "Store<\(stateName), \(actionName)> was deallocated while processing an action."

        XCTAssertEqual(error.description, expected)
    }

    func testReduxErrorStoreDeallocatedCarriesTypes() {
        let error = ReduxError.storeDeallocated(TestState.self, TestAction.self)

        guard case let .storeDeallocated(state, action) = error else {
            return XCTFail("Expected storeDeallocated error.")
        }

        XCTAssertEqual(ObjectIdentifier(state), ObjectIdentifier(TestState.self))
        XCTAssertEqual(ObjectIdentifier(action), ObjectIdentifier(TestAction.self))
    }

    func testReducersRunInProvidedOrder() {
        let state = TestState()
        let reducerA = Reducer<TestState, TestAction>(id: "r1") { context in
            context.state.log.append("r1")
        }
        let reducerB = Reducer<TestState, TestAction>(id: "r2") { context in
            context.state.log.append("r2")
        }
        let store = Store(
            initialState: state,
            middlewares: [],
            reducers: [reducerA, reducerB],
            onException: { _ in XCTFail("Unexpected error in reducer order test.") }
        )

        store.dispatch(.run)

        XCTAssertEqual(state.log, ["r1", "r2"])
    }

    func testMiddlewareOrderIsPreserved() {
        let state = TestState()
        var calls: [String] = []
        let middlewareA = Middleware<TestState, TestAction>(id: "m1") { context in
            calls.append("m1.before")
            try context.next(context.action)
            calls.append("m1.after")
        }
        let middlewareB = Middleware<TestState, TestAction>(id: "m2") { context in
            calls.append("m2.before")
            try context.next(context.action)
            calls.append("m2.after")
        }
        let reducer = Reducer<TestState, TestAction>(id: "r") { _ in
            calls.append("reducer")
        }
        let store = Store(
            initialState: state,
            middlewares: [middlewareA, middlewareB],
            reducers: [reducer],
            onException: { _ in XCTFail("Unexpected error in middleware order test.") }
        )

        store.dispatch(.run)

        XCTAssertEqual(calls, ["m1.before", "m2.before", "reducer", "m2.after", "m1.after"])
    }

    func testMaxDispatchableDropsDuplicateBufferedActions() {
        let state = TestState()
        let reducer = Reducer<TestState, TestAction>(id: "inc") { context in
            context.state.value += 1
        }
        let store = Store(
            initialState: state,
            middlewares: [],
            reducers: [reducer],
            onException: { _ in XCTFail("Unexpected error in maxDispatchable test.") }
        )
        let action = TestAction.inc

        store.dispatch(maxDispatchable: 1, action, action, action)

        XCTAssertEqual(state.value, 1)
    }

    func testStoreDeallocatesAfterDispatch() {
        let state = TestState()
        let reducer = Reducer<TestState, TestAction>(id: "noop") { _ in }
        weak var weakStore: Store<TestState, TestAction>?
        do {
            let store = Store(
                initialState: state,
                middlewares: [],
                reducers: [reducer],
                onException: { _ in XCTFail("Unexpected error in deallocation test.") }
            )
            weakStore = store
            store.dispatch(.run)
        }

        XCTAssertNil(weakStore)
    }

    func testStoreDeallocatesAfterManyActions() {
        let state = TestState()
        let reducer = Reducer<TestState, TestAction>(id: "inc") { context in
            context.state.value += 1
        }
        let totalActions = 1000
        weak var weakStore: Store<TestState, TestAction>?
        do {
            let store = Store(
                initialState: state,
                middlewares: [],
                reducers: [reducer],
                onException: { _ in XCTFail("Unexpected error in mass dispatch test.") }
            )
            weakStore = store

            for _ in 0..<totalActions {
                store.dispatch(.inc)
            }
        }

        XCTAssertEqual(state.value, totalActions)

        XCTAssertNil(weakStore)
    }

    func testStoreDeallocatesAfterManyAsyncActions() async {
        let state = TestState()
        let totalActions = 200
        let expectation = expectation(description: "Async actions complete")
        expectation.expectedFulfillmentCount = totalActions
        let reducer = Reducer<TestState, TestAction>(id: "inc") { context in
            guard context.action == .inc else { return }
            context.state.value += 1
            expectation.fulfill()
        }
        let middleware = Middleware<TestState, TestAction>(id: "async") { context in
            if context.action == .run {
                Task { @MainActor in
                    await Task.yield()
                    context.dispatch(0, .inc)
                }
            }
            try context.next(context.action)
        }
        weak var weakStore: Store<TestState, TestAction>?
        do {
            let store = Store(
                initialState: state,
                middlewares: [middleware],
                reducers: [reducer],
                onException: { _ in XCTFail("Unexpected error in async mass dispatch test.") }
            )
            weakStore = store

            for _ in 0..<totalActions {
                store.dispatch(.run)
            }

            await fulfillment(of: [expectation], timeout: 2.0)

            XCTAssertEqual(state.value, totalActions)
        }

        XCTAssertNil(weakStore)
    }
}
