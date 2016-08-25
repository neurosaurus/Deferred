//
//  TaskMap.swift
//  Deferred
//
//  Created by Zachary Waldowski on 10/27/15.
//  Copyright © 2015-2016 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
import Result
#endif
import Dispatch

private func commonMapSuccess<OldResult: ResultType, NewSuccessValue>(_ transform: @escaping(OldResult.Value) throws -> NewSuccessValue) -> (OldResult) -> TaskResult<NewSuccessValue> {
    return { oldResult in
        TaskResult {
            try transform(oldResult.extract())
        }
    }
}

extension TaskType {
    private typealias OldSuccessValue = Value.Value

    /// Returns a `Task` containing the result of mapping `transform` over the
    /// task's success value.
    ///
    /// `map` submits the `transform` to the `executor` once the task completes.
    ///
    /// The resulting task is cancellable in the same way the recieving task is.
    ///
    /// - seealso: FutureType.map(upon:_:)
    public func map<NewSuccessValue>(upon executor: ExecutorType, _ transform: @escaping(OldSuccessValue) throws -> NewSuccessValue) -> Task<NewSuccessValue> {
        let future = map(upon: executor, commonMapSuccess(transform))
        return .init(future, cancellation: cancel)
    }

    /// Returns a `Task` containing the result of mapping `transform` over the
    /// task's success value
    ///
    /// `map` executes the `transform` asynchronously once the task completes.
    ///
    /// The resulting task is cancellable in the same way the recieving task is.
    ///
    /// - seealso: FutureType.map(upon:_:)
    public func map<NewSuccessValue>(upon queue: DispatchQueue, _ transform: @escaping(OldSuccessValue) throws -> NewSuccessValue) -> Task<NewSuccessValue> {
        let future = map(upon: queue, commonMapSuccess(transform))
        return .init(future, cancellation: cancel)
    }

    /// Returns a `Task` containing the result of mapping `transform` over the
    /// task's success value
    ///
    /// `map` executes the `transform` in the background once the task completes.
    ///
    /// The resulting task is cancellable in the same way the recieving task is.
    ///
    /// - seealso: FutureType.map(_:)
    public func map<NewSuccessValue>(_ transform: @escaping(OldSuccessValue) throws -> NewSuccessValue) -> Task<NewSuccessValue> {
        let future = map(commonMapSuccess(transform))
        return .init(future, cancellation: cancel)
    }
}
