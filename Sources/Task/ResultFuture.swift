//
//  ResultFuture.swift
//  Deferred
//
//  Created by Zachary Waldowski on 12/26/15.
//  Copyright © 2015-2016 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
import Result
#endif
import Dispatch

private func commonUponSuccess<Result: ResultType>(_ body: @escaping(Result.Value) -> Void) -> (Result) -> Void {
    return { result in
        result.withValues(ifSuccess: body, ifFailure: { _ in () })
    }
}

private func commonUponFailure<Result: ResultType>(_ body: @escaping(Error) -> Void) -> (Result) -> Void {
    return { result in
        result.withValues(ifSuccess: { _ in () }, ifFailure: body)
    }
}

extension FutureType where Value: ResultType {
    /// Call some `body` closure if the future successfully resolves a value.
    ///
    /// - parameter executor: A context for handling the `body` on fill.
    /// - parameter body: A closure that uses the determined success value.
    /// - seealso: upon(_:body:)
    public func uponSuccess(_ executor: ExecutorType, _ body: @escaping(Value.Value) -> Void) {
        upon(executor, body: commonUponSuccess(body))
    }

    /// Call some `body` closure if the future produces an error.
    ///
    /// - parameter executor: A context for handling the `body` on fill.
    /// - parameter body: A closure that uses the determined failure value.
    /// - seealso: upon(_:body:)
    public func uponFailure(_ executor: ExecutorType, _ body: @escaping(Error) -> Void) {
        upon(executor, body: commonUponFailure(body))
    }

    /// Call some `body` closure if the future successfully resolves a value.
    ///
    /// - seealso: `uponSuccess(_:body:)`.
    /// - seealso: `upon(_:body:)`.
    public func uponSuccess(_ queue: DispatchQueue, _ body: @escaping(Value.Value) -> Void) {
        upon(queue, body: commonUponSuccess(body))
    }

    /// Call some `body` closure if the future produces an error.
    ///
    /// - seealso: `uponFailure(_:body:)`.
    /// - seealso: `upon(_:body:)`.
    public func uponFailure(_ queue: DispatchQueue, _ body: @escaping(Error) -> Void) {
        upon(queue, body: commonUponFailure(body))
    }

    /// Call some `body` in the background if the future successfully resolves
    /// a value.
    ///
    /// - seealso: `uponSuccess(_:body:)`.
    public func uponSuccess(_ body: @escaping(Value.Value) -> Void) {
        upon(Self.genericQueue, body: commonUponSuccess(body))
    }

    /// Call some `body` in the background if the future produces an error.
    ///
    /// - seealso: `uponFailure(_:body:)`.
    public func uponFailure(_ body: @escaping(Error) -> Void) {
        upon(Self.genericQueue, body: commonUponFailure(body))
    }
}

// MARK: -

/// A `FutureType` whose determined element is that of a `Base` future passed
/// through a transform function returning `NewValue`. This value is computed
/// each time it is read through a call to `upon(queue:body:)`.
private struct LazyMapFuture<Base: FutureType, NewValue>: FutureType {

    let base: Base
    let transform: (Base.Value) -> NewValue
    init(_ base: Base, transform: @escaping(Base.Value) -> NewValue) {
        self.base = base
        self.transform = transform
    }

    /// Call some function `body` once the value becomes determined.
    ///
    /// If the value is determined, the function will be submitted to the
    /// queue immediately. An upon call is always executed asynchronously.
    ///
    /// - parameter queue: A dispatch queue to execute the function `body` on.
    /// - parameter body: A function that uses the delayed value.
    func upon(_ executor: ExecutorType, body: @escaping(NewValue) -> Void) {
        return base.upon(executor) { [transform] in
            body(transform($0))
        }
    }

    /// Waits synchronously, for a maximum `time`, for the calculated value to
    /// become determined; otherwise, returns `nil`.
    func wait(_ time: Timeout) -> NewValue? {
        return base.wait(time).map(transform)
    }
    
}

extension Future where Value: ResultType {
    /// Create a future having the same underlying task as `other`.
    public init<Other: FutureType>(task other: Other) where Other.Value: ResultType, Other.Value.Value == Value.Value {
        self.init(LazyMapFuture(other) {
            Value(with: $0.extract)
        })
    }
}
