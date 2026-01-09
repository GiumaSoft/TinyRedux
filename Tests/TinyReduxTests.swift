//


import Foundation
import Observation
import Testing
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
    var description: String {
        switch self {
        case .run:
            "run"
        case .inc:
            "inc"
        }
    }
    var debugDescription: String { description }
}

@Suite(.serialized)
@MainActor
struct TinyReduxTests {

    @Test
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
                #expect(Bool(false), "Unexpected error in reducer order test: \(context.error)")
            }],
            reducers: [reducerA, reducerB]
        )

        store.dispatch(.run)

        #expect(state.log == ["r1", "r2"])
    }

    @Test
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
                #expect(Bool(false), "Unexpected error in middleware order test: \(context.error)")
            }],
            reducers: [reducer]
        )

        store.dispatch(.run)

        #expect(calls == ["m1.before", "m2.before", "reducer", "m2.after", "m1.after"])
    }

    @Test
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
                #expect(Bool(false), "Unexpected error in maxDispatchable test: \(context.error)")
            }],
            reducers: [reducer]
        )
        let action = TestAction.inc

        store.dispatch(maxDispatchable: 1, action, action, action)

        #expect(state.value == 1)
    }

    @Test
    func testSharedInstanceReturnsSameStore() {
        let state = TestState()
        let reducer = Reducer<TestState, TestAction>(id: "noop") { _ in }
        let storeA = Store.sharedInstance(
            override: true,
            initialState: state,
            middlewares: [],
            resolvers: [Resolver(id: "resolver") { context in
                #expect(Bool(false), "Unexpected error in shared instance test: \(context.error)")
            }],
            reducers: [reducer]
        )
        let storeB = Store.sharedInstance(
            initialState: state,
            middlewares: [],
            resolvers: [Resolver(id: "resolver") { context in
                #expect(Bool(false), "Unexpected error in shared instance test: \(context.error)")
            }],
            reducers: [reducer]
        )

        #expect(storeA === storeB)
    }

    @Test
    func testSharedInstanceOverridesWhenRequested() {
        let state = TestState()
        let reducer = Reducer<TestState, TestAction>(id: "noop") { _ in }
        let storeA = Store.sharedInstance(
            override: true,
            initialState: state,
            middlewares: [],
            resolvers: [Resolver(id: "resolver") { context in
                #expect(Bool(false), "Unexpected error in shared instance override test: \(context.error)")
            }],
            reducers: [reducer]
        )
        let storeB = Store.sharedInstance(
            override: true,
            initialState: state,
            middlewares: [],
            resolvers: [Resolver(id: "resolver") { context in
                #expect(Bool(false), "Unexpected error in shared instance override test: \(context.error)")
            }],
            reducers: [reducer]
        )

        #expect(storeA !== storeB)
    }

    @Test
    func testMeasurePerformanceReturnsPartialIntervals() {
        let state = TestState()
        let reducer = Reducer<TestState, TestAction>(id: "noop") { _ in }
        let store = Store.sharedInstance(
            override: true,
            initialState: state,
            middlewares: [],
            resolvers: [Resolver(id: "resolver") { context in
                #expect(Bool(false), "Unexpected error in measure performance test: \(context.error)")
            }],
            reducers: [reducer]
        )
        var first: UInt64 = 0
        var second: UInt64 = 0

        store.measurePerformance { runTime in
            Thread.sleep(forTimeInterval: 0.03)
            first = runTime()
            Thread.sleep(forTimeInterval: 0.005)
            second = runTime()
        }

        #expect(first > 0)
        #expect(second > 0)
        #expect(second < first)
    }

    @Test
    func testDeferredNextCanInterleaveReducerCompletionOrder() async {
        let state = TestState()
        let middleware = Middleware<TestState, TestAction>(id: "deferred-next") { context in
            let (_, _, next, action) = context.args

            switch action {
            case .run:
                context.runTask {
                    try await Task.sleep(nanoseconds: 30_000_000)
                    try await MainActor.run {
                        try next(action)
                    }
                }
                return
            default:
                break
            }

            try next(action)
        }
        let reducer = Reducer<TestState, TestAction>(id: "record-order") { context in
            let (state, action) = context.args
            switch action {
            case .run:
                state.log.append("run")
            case .inc:
                state.log.append("inc")
            }
        }
        let store = Store.sharedInstance(
            override: true,
            initialState: state,
            middlewares: [middleware],
            resolvers: [Resolver(id: "resolver") { context in
                #expect(Bool(false), "Unexpected error in deferred next test: \(context.error)")
            }],
            reducers: [reducer]
        )

        store.dispatch(.run)
        store.dispatch(.inc)

        for _ in 0..<500 where state.log.count < 2 {
            try? await Task.sleep(nanoseconds: 2_000_000)
        }

        #expect(state.log == ["inc", "run"])
    }
}
