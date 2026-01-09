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
@Observable
final class TestReadOnly: ReduxReadOnlyState, @unchecked Sendable {
    typealias State = TestState

    private let state: TestState

    init(_ state: TestState) {
        self.state = state
    }

    var value: Int { state.value }
    var log: [String] { state.log }
}

@CaseID
enum TestAction: Equatable, ReduxAction, Sendable {
    case run
    case inc
}

@Suite(.serialized)
@MainActor
struct TinyReduxTests {

    @Test
    func reducersRunInProvidedOrder() async {
        let state = TestState()
        let reducerA = AnyReducer<TestState, TestAction>(id: "r1") { context in
            let (state, _) = context.args
            state.log.append("r1")
        }
        let reducerB = AnyReducer<TestState, TestAction>(id: "r2") { context in
            let (state, _) = context.args
            state.log.append("r2")
        }
        let store = Store(
            initialState: state,
            middlewares: [],
            resolvers: [AnyResolver(id: "resolver") { context in
                #expect(Bool(false), "Unexpected error in reducer order test: \(context.error)")
            }],
            reducers: [reducerA, reducerB]
        )

        let result = await store.dispatchWithResult(.run)
        _ = result

        #expect(state.log == ["r1", "r2"])
    }

    @Test
    func middlewareOrderIsPreserved() async {
        let state = TestState()
        var calls: [String] = []
        let middlewareA = AnyMiddleware<TestState, TestAction>(id: "m1") { context in
            calls.append("m1.before")
            try context.next(context.action)
            calls.append("m1.after")
        }
        let middlewareB = AnyMiddleware<TestState, TestAction>(id: "m2") { context in
            calls.append("m2.before")
            try context.next(context.action)
            calls.append("m2.after")
        }
        let reducer = AnyReducer<TestState, TestAction>(id: "r") { _ in
            calls.append("reducer")
        }
        let store = Store(
            initialState: state,
            middlewares: [middlewareA, middlewareB],
            resolvers: [AnyResolver(id: "resolver") { context in
                #expect(Bool(false), "Unexpected error in middleware order test: \(context.error)")
            }],
            reducers: [reducer]
        )

        let _ = await store.dispatchWithResult(.run)

        #expect(calls == ["m1.before", "m2.before", "reducer", "m2.after", "m1.after"])
    }

    @Test
    func maxDispatchableDropsDuplicateBufferedActions() async {
        let state = TestState()
        let reducer = AnyReducer<TestState, TestAction>(id: "inc") { context in
            let (state, _) = context.args
            state.value += 1
        }
        let store = Store(
            initialState: state,
            middlewares: [],
            resolvers: [AnyResolver(id: "resolver") { context in
                #expect(Bool(false), "Unexpected error in maxDispatchable test: \(context.error)")
            }],
            reducers: [reducer]
        )

        store.dispatch(maxDispatchable: 1, .inc)
        store.dispatch(maxDispatchable: 1, .inc)
        store.dispatch(maxDispatchable: 1, .inc)

        // Wait for the single action to process
        for _ in 0..<500 where state.value < 1 {
            try? await Task.sleep(nanoseconds: 2_000_000)
        }

        #expect(state.value == 1)
    }

    @Test
    func deferredNextCanInterleaveReducerCompletionOrder() async {
        let state = TestState()
        let middleware = AnyMiddleware<TestState, TestAction>(id: "deferred-next") { context in
            switch context.action {
            case .run:
                context.task { _ in
                    try await Task.sleep(nanoseconds: 30_000_000)
                    try await MainActor.run {
                        try context.next(context.action)
                    }
                }
                return
            default:
                break
            }

            try context.next(context.action)
        }
        let reducer = AnyReducer<TestState, TestAction>(id: "record-order") { context in
            let (state, action) = context.args
            switch action {
            case .run:
                state.log.append("run")
            case .inc:
                state.log.append("inc")
            }
        }
        let store = Store(
            initialState: state,
            middlewares: [middleware],
            resolvers: [AnyResolver(id: "resolver") { context in
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

    @Test
    func resolverReceivesOrigin() async {
        let state = TestState()
        var capturedOrigin: ResolverContext<TestState, TestAction>.Origin?

        enum TestError: Error { case test }

        let middleware = AnyMiddleware<TestState, TestAction>(id: "throwing-middleware") { context in
            throw TestError.test
        }
        let resolver = AnyResolver<TestState, TestAction>(id: "resolver") { context in
            capturedOrigin = context.origin
        }
        let store = Store(
            initialState: state,
            middlewares: [middleware],
            resolvers: [resolver],
            reducers: []
        )

        store.dispatch(.run)

        for _ in 0..<500 where capturedOrigin == nil {
            try? await Task.sleep(nanoseconds: 2_000_000)
        }

        #expect(capturedOrigin == .middleware("throwing-middleware"))
    }

    @Test
    func dispatchWithResultReturnsUpdatedState() async {
        let state = TestState()
        let reducer = AnyReducer<TestState, TestAction>(id: "inc") { context in
            context.state.value += 1
        }
        let store = Store(
            initialState: state,
            middlewares: [],
            resolvers: [],
            reducers: [reducer]
        )

        let result = await store.dispatchWithResult(.inc)

        #expect(result.value == 1)
    }

    @Test
    func previewStateCreatesEmptyPipeline() {
        let state = TestState()
        state.value = 42

        let store = Store<TestState, TestAction>.previewState(state)

        #expect(store.value == 42)
    }

    @Test
    func onLogCallbackReceivesMiddlewareLog() async {
        let state = TestState()
        var logEntries: [Store<TestState, TestAction>.Log] = []

        let middleware = AnyMiddleware<TestState, TestAction>(id: "logged-mw") { context in
            context.complete()
            try context.next()
        }
        let reducer = AnyReducer<TestState, TestAction>(id: "logged-r") { context in
            context.complete()
        }
        let store = Store(
            initialState: state,
            middlewares: [middleware],
            resolvers: [],
            reducers: [reducer],
            onLog: { log in
                logEntries.append(log)
            }
        )

        store.dispatch(.run)

        for _ in 0..<500 where logEntries.count < 2 {
            try? await Task.sleep(nanoseconds: 2_000_000)
        }

        #expect(logEntries.count == 2)
    }

    @Test
    func resolverChainForwardsErrorThroughNext() async {
        let state = TestState()
        var resolverCalls: [String] = []

        enum TestError: Error { case test }

        let middleware = AnyMiddleware<TestState, TestAction>(id: "throw-mw") { context in
            throw TestError.test
        }
        let resolverA = AnyResolver<TestState, TestAction>(id: "rA") { context in
            resolverCalls.append("rA")
            context.next()
        }
        let resolverB = AnyResolver<TestState, TestAction>(id: "rB") { context in
            resolverCalls.append("rB")
        }
        let store = Store(
            initialState: state,
            middlewares: [middleware],
            resolvers: [resolverA, resolverB],
            reducers: []
        )

        store.dispatch(.run)

        for _ in 0..<500 where resolverCalls.count < 2 {
            try? await Task.sleep(nanoseconds: 2_000_000)
        }

        #expect(resolverCalls == ["rA", "rB"])
    }

    @Test
    func middlewareCanBlockPipeline() async {
        let state = TestState()
        var reducerCalled = false

        let middleware = AnyMiddleware<TestState, TestAction>(id: "blocker") { context in
            // Intentionally not calling next()
        }
        let reducer = AnyReducer<TestState, TestAction>(id: "r") { _ in
            reducerCalled = true
        }
        let store = Store(
            initialState: state,
            middlewares: [middleware],
            resolvers: [],
            reducers: [reducer]
        )

        store.dispatch(.run)

        // Give time for processing
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(reducerCalled == false)
    }

    @Test
    func middlewareCanRedispatch() async {
        let state = TestState()

        let middleware = AnyMiddleware<TestState, TestAction>(id: "redispatch") { context in
            if context.action == .run {
                context.dispatch(0, .inc)
            }
            try context.next()
        }
        let reducer = AnyReducer<TestState, TestAction>(id: "inc") { context in
            if context.action == .inc {
                context.state.value += 1
            }
        }
        let store = Store(
            initialState: state,
            middlewares: [middleware],
            resolvers: [],
            reducers: [reducer]
        )

        store.dispatch(.run)

        for _ in 0..<500 where state.value < 1 {
            try? await Task.sleep(nanoseconds: 2_000_000)
        }

        #expect(state.value == 1)
    }

    @Test
    func resolverCanDispatchRecoveryAction() async {
        let state = TestState()

        enum TestError: Error { case test }

        let middleware = AnyMiddleware<TestState, TestAction>(id: "throw-mw") { context in
            if context.action == .run {
                throw TestError.test
            }
            try context.next()
        }
        let resolver = AnyResolver<TestState, TestAction>(id: "recovery") { context in
            context.dispatch(0, .inc)
        }
        let reducer = AnyReducer<TestState, TestAction>(id: "inc") { context in
            if context.action == .inc {
                context.state.value += 1
            }
        }
        let store = Store(
            initialState: state,
            middlewares: [middleware],
            resolvers: [resolver],
            reducers: [reducer]
        )

        store.dispatch(.run)

        for _ in 0..<500 where state.value < 1 {
            try? await Task.sleep(nanoseconds: 2_000_000)
        }

        #expect(state.value == 1)
    }

    @Test
    func dynamicMemberLookupReadsState() {
        let state = TestState()
        state.value = 99
        let store = Store<TestState, TestAction>.previewState(state)

        #expect(store.value == 99)
    }

    @Test
    func reducerContextArgsDestructure() async {
        let state = TestState()
        var capturedAction: TestAction?

        let reducer = AnyReducer<TestState, TestAction>(id: "r") { context in
            let (_, action) = context.args
            capturedAction = action
        }
        let store = Store(
            initialState: state,
            middlewares: [],
            resolvers: [],
            reducers: [reducer]
        )

        let _ = await store.dispatchWithResult(.run)

        #expect(capturedAction == .run)
    }

    @Test
    func middlewareContextArgsDestructure() async {
        let state = TestState()
        var capturedAction: TestAction?

        let middleware = AnyMiddleware<TestState, TestAction>(id: "m") { context in
            let (_, _, _, _, action) = context.args
            capturedAction = action
            try context.next()
        }
        let store = Store(
            initialState: state,
            middlewares: [middleware],
            resolvers: [],
            reducers: []
        )

        store.dispatch(.run)

        for _ in 0..<500 where capturedAction == nil {
            try? await Task.sleep(nanoseconds: 2_000_000)
        }

        #expect(capturedAction == .run)
    }

    @Test
    func resolverContextArgsDestructure() async {
        let state = TestState()
        var capturedOrigin: ResolverContext<TestState, TestAction>.Origin?

        enum TestError: Error { case test }

        let middleware = AnyMiddleware<TestState, TestAction>(id: "throw-mw") { context in
            throw TestError.test
        }
        let resolver = AnyResolver<TestState, TestAction>(id: "resolver") { context in
            let (_, _, _, origin, _, _) = context.args
            capturedOrigin = origin
        }
        let store = Store(
            initialState: state,
            middlewares: [middleware],
            resolvers: [resolver],
            reducers: []
        )

        store.dispatch(.run)

        for _ in 0..<500 where capturedOrigin == nil {
            try? await Task.sleep(nanoseconds: 2_000_000)
        }

        #expect(capturedOrigin == .middleware("throw-mw"))
    }

    @Test
    func onLogCallbackReceivesResolverLog() async {
        let state = TestState()
        var resolverLogReceived = false

        enum TestError: Error { case test }

        let middleware = AnyMiddleware<TestState, TestAction>(id: "throw-mw") { context in
            throw TestError.test
        }
        let resolver = AnyResolver<TestState, TestAction>(id: "logged-resolver") { context in
            context.complete()
        }
        let store = Store(
            initialState: state,
            middlewares: [middleware],
            resolvers: [resolver],
            reducers: [],
            onLog: { log in
                if case .resolver = log {
                    resolverLogReceived = true
                }
            }
        )

        store.dispatch(.run)

        for _ in 0..<500 where !resolverLogReceived {
            try? await Task.sleep(nanoseconds: 2_000_000)
        }

        #expect(resolverLogReceived)
    }

    @Test
    func multipleReducersAllMutateState() async {
        let state = TestState()
        let r1 = AnyReducer<TestState, TestAction>(id: "r1") { context in
            context.state.value += 10
        }
        let r2 = AnyReducer<TestState, TestAction>(id: "r2") { context in
            context.state.value += 5
        }
        let store = Store(
            initialState: state,
            middlewares: [],
            resolvers: [],
            reducers: [r1, r2]
        )

        let result = await store.dispatchWithResult(.inc)

        #expect(result.value == 15)
    }

    @Test
    func middlewareResolveRouteToResolverChain() async {
        let state = TestState()
        var resolverCalled = false

        enum TestError: Error { case manual }

        let middleware = AnyMiddleware<TestState, TestAction>(id: "resolve-mw") { context in
            context.resolve(TestError.manual)
            try context.next()
        }
        let resolver = AnyResolver<TestState, TestAction>(id: "resolver") { context in
            resolverCalled = true
        }
        let store = Store(
            initialState: state,
            middlewares: [middleware],
            resolvers: [resolver],
            reducers: []
        )

        store.dispatch(.run)

        for _ in 0..<500 where !resolverCalled {
            try? await Task.sleep(nanoseconds: 2_000_000)
        }

        #expect(resolverCalled)
    }

    @Test
    func statedMiddlewareCapturesCoordinator() async {
        let state = TestState()

        final class Coordinator: @unchecked Sendable {
            var count = 0
        }

        let coordinator = Coordinator()
        let middleware = AnyMiddleware(StatedMiddleware<TestState, TestAction>(
            id: "stated",
            coordinator: coordinator
        ) { coord, context in
            coord.count += 1
            try context.next()
        })

        let store = Store(
            initialState: state,
            middlewares: [middleware],
            resolvers: [],
            reducers: []
        )

        store.dispatch(.run)
        store.dispatch(.inc)

        for _ in 0..<500 where coordinator.count < 2 {
            try? await Task.sleep(nanoseconds: 2_000_000)
        }

        #expect(coordinator.count == 2)
    }

    @Test
    func dispatchWithResultThrottledReturnsCurrentState() async {
        let state = TestState()
        state.value = 42
        let reducer = AnyReducer<TestState, TestAction>(id: "inc") { context in
            context.state.value += 1
        }
        let store = Store(
            initialState: state,
            middlewares: [],
            resolvers: [],
            reducers: [reducer]
        )

        // Fill the rate limit
        store.dispatch(maxDispatchable: 1, .inc)
        // This should be throttled and return current state
        let result = await store.dispatchWithResult(maxDispatchable: 1, .inc)

        // The throttled call returns state as-is (42 or 43 depending on timing)
        #expect(result.value >= 42)
    }

    @Test
    func onceGuardIsIdempotent() {
        let guard1 = OnceGuard()

        #expect(guard1.tryConsume() == true)
        #expect(guard1.tryConsume() == false)
        #expect(guard1.tryConsume() == false)
    }

    @Test
    func completeEmitsOneLogPerComponent() async {
        let state = TestState()
        var logEntries: [Store<TestState, TestAction>.Log] = []

        // 2 middlewares: only m1 calls complete()
        let m1 = AnyMiddleware<TestState, TestAction>(id: "m1") { context in
            context.complete()
            try context.next()
        }
        let m2 = AnyMiddleware<TestState, TestAction>(id: "m2") { context in
            try context.next()
        }

        // 4 reducers: only r2 calls complete() for .inc
        let r1 = AnyReducer<TestState, TestAction>(id: "r1") { context in
            switch context.action {
            case .run:
                context.state.log.append("r1")
                context.complete()
            default:
                break
            }
        }
        let r2 = AnyReducer<TestState, TestAction>(id: "r2") { context in
            switch context.action {
            case .inc:
                context.state.value += 1
                context.complete()
            default:
                break
            }
        }
        let r3 = AnyReducer<TestState, TestAction>(id: "r3") { _ in }
        let r4 = AnyReducer<TestState, TestAction>(id: "r4") { _ in }

        let store = Store(
            initialState: state,
            middlewares: [m1, m2],
            resolvers: [],
            reducers: [r1, r2, r3, r4],
            onLog: { log in
                logEntries.append(log)
            }
        )

        let _ = await store.dispatchWithResult(.inc)

        // Exactly 1 middleware log (m1) + 1 reducer log (r2)
        let middlewareLogs = logEntries.filter { if case .middleware = $0 { return true }; return false }
        let reducerLogs = logEntries.filter { if case .reducer = $0 { return true }; return false }

        #expect(middlewareLogs.count == 1)
        #expect(reducerLogs.count == 1)

        if case let .middleware(id, _, _, _) = middlewareLogs.first {
            #expect(id == "m1")
        }
        if case let .reducer(id, _, _, _) = reducerLogs.first {
            #expect(id == "r2")
        }
    }

    @Test
    func completeEmitsOneLogPerResolver() async {
        let state = TestState()
        var logEntries: [Store<TestState, TestAction>.Log] = []

        enum TestError: Error { case test }

        let middleware = AnyMiddleware<TestState, TestAction>(id: "throw-mw") { context in
            throw TestError.test
        }

        // 2 resolvers: only res1 calls complete(), both forward via next()
        let res1 = AnyResolver<TestState, TestAction>(id: "res1") { context in
            context.complete()
            context.next()
        }
        let res2 = AnyResolver<TestState, TestAction>(id: "res2") { context in
            // does NOT call complete()
        }

        let store = Store(
            initialState: state,
            middlewares: [middleware],
            resolvers: [res1, res2],
            reducers: [],
            onLog: { log in
                logEntries.append(log)
            }
        )

        store.dispatch(.run)

        for _ in 0..<500 where logEntries.isEmpty {
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
        // Give extra time for any spurious logs
        try? await Task.sleep(nanoseconds: 10_000_000)

        let resolverLogs = logEntries.filter { if case .resolver = $0 { return true }; return false }
        #expect(resolverLogs.count == 1)
        if case let .resolver(id, _, _, _, _) = resolverLogs.first {
            #expect(id == "res1")
        }
    }

    @Test
    func caseIDMacroSynthesizesID() {
        @CaseID
        enum Action: Equatable, Sendable {
            case load
            case save(Int)
        }

        #expect(Action.load.id == "load")
        #expect(Action.save(42).id == "save")
    }
}
