//
//  TaskCollections.swift
//  Deferred
//
//  Created by Zachary Waldowski on 11/18/15.
//  Copyright © 2015-2016 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
import Result
#endif
import Dispatch

extension Collection where Iterator.Element: TaskType {
    /// Compose a number of tasks into a single notifier task.
    ///
    /// If any of the contained tasks fail, the returned task will be determined
    /// with that failure. Otherwise, once all operations succeed, the returned
    /// task will be determined a success.
    public var joinedTasks: Task<Void> {
        if isEmpty {
            return Task(value: ())
        }

        let group = DispatchGroup()
        let coalescingDeferred = Deferred<Task<Void>.Result>()
        var cancellations = [Cancellation]()
        cancellations.reserveCapacity(numericCast(underestimatedCount))

        for task in self {
            cancellations.append(task.cancel)

            group.enter()
            task.upon { result in
                result.withValues(ifSuccess: { _ in }, ifFailure: { error in
                    _ = coalescingDeferred.fill(.failure(error))
                })
                group.leave()
            }
        }

        group.notify(queue: Task<Void>.genericQueue) {
            _ = coalescingDeferred.fill(.success())
        }

        return Task(coalescingDeferred) { _ in
            for function in cancellations {
                function()
            }
        }
    }
}
