//
//  TaskTests.swift
//  DeferredTests
//
//  Created by John Gallagher on 7/1/15.
//  Copyright © 2015-2016 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
#if SWIFT_PACKAGE
import Result
import Deferred
@testable import Task
#else
@testable import Deferred
#endif

private extension XCTestCase {

    func impossible<T, U>(_ value: T) -> U {
        XCTFail("Unreachable code in test")
        repeat {
            RunLoop.current.run()
        } while true
    }

}

class TaskTests: XCTestCase {

    func testUponSuccess() {
        let d = Deferred<Task<Int>.Result>()
        let task = Task(d, cancellation: {})
        let expectation = self.expectation(description: "upon is called")

        task.uponSuccess { _ in expectation.fulfill() }
        task.uponFailure(impossible)

        d.succeed(1)

        waitForExpectations()
    }

    func testUponFailure() {
        let d = Deferred<Task<Int>.Result>()
        let task = Task(d, cancellation: {})
        let expectation = self.expectation(description: "upon is called")

        task.uponSuccess(impossible)
        task.uponFailure { _ in expectation.fulfill() }

        d.fail(Error.first)

        waitForExpectations()
    }

    func testThatMapPassesThroughErrors() {
        let beforeExpectation = expectation(description: "original task filled")
        let beforeTask: Task<Int> = Task(error: Error.first)

        let afterExpectation = expectation(description: "mapped filled with same error")
        let afterTask: Task<String> = beforeTask.map(impossible)

        beforeTask.upon {
            XCTAssertEqual($0.error as? Error, .first)
            beforeExpectation.fulfill()
        }

        afterTask.upon {
            XCTAssertEqual($0.error as? Error, .first)
            afterExpectation.fulfill()
        }

        waitForExpectations()
    }

    func testThatThrowingMapSubstitutesWithError() {
        let beforeExpectation = expectation(description: "original task filled")
        let beforeTask: Task<Int> = Task(value: -1)

        let afterExpectation = expectation(description: "mapped filled with error")
        let afterTask: Task<String> = beforeTask.map { _ in
            throw Error.second
        }

        beforeTask.upon {
            XCTAssertEqual($0.value, -1)
            beforeExpectation.fulfill()
        }

        afterTask.upon {
            XCTAssertEqual($0.error as? Error, .second)
            afterExpectation.fulfill()
        }

        waitForExpectations()
    }

    func testThatFlatMapForwardsCancellationToSubsequentTask() {
        let beforeTask = Task<Int>(value: 1)

        let afterExpectation = expectation(description: "flatMapped task is cancelled")
        let afterTask: Task<String> = beforeTask.flatMap { _ in
            return Task(Future(), cancellation: afterExpectation.fulfill)
        }

        afterTask.cancel()

        waitForExpectations()
    }

    func testThatThrowingFlatMapSubstitutesWithError() {
        let beforeTask = Task<Int>(value: 1)

        let afterExpectation = expectation(description: "flatMapped task is cancelled")
        let afterTask: Task<String> = beforeTask.flatMap { _ -> Task<String> in
            throw Error.second
        }

        afterTask.uponFailure {
            XCTAssertEqual($0 as? Error, .second)
            afterExpectation.fulfill()
        }

        waitForExpectations()
    }

    func testThatRecoverPassesThroughValues() {
        let beforeExpectation = expectation(description: "original task filled")
        let beforeTask: Task<Int> = Task(value: 1)

        let afterExpectation = expectation(description: "mapped filled with same error")
        let afterTask: Task<Int> = beforeTask.recover(impossible)

        beforeTask.upon {
            XCTAssertEqual($0.value, 1)
            beforeExpectation.fulfill()
        }

        afterTask.upon {
            XCTAssertNil($0.error)
            afterExpectation.fulfill()
        }

        waitForExpectations()
    }

    func testThatRecoverMapsFailures() {
        let beforeExpectation = expectation(description: "original task filled")
        let beforeTask: Task<Int> = Task(error: Error.first)

        let afterExpectation = expectation(description: "mapped filled with same error")
        let afterTask: Task<Int> = beforeTask.recover { _ in 42 }

        beforeTask.upon {
            XCTAssertEqual($0.error as? Error, .first)
            beforeExpectation.fulfill()
        }

        afterTask.upon {
            XCTAssertEqual($0.value, 42)
            afterExpectation.fulfill()
        }

        waitForExpectations()
    }

}

class TaskCustomExecutorTests: CustomExecutorTestCase {

    func testUponSuccess() {
        let d = Deferred<Task<Int>.Result>()
        let task = Task(d, cancellation: {})
        let expectation = self.expectation(description: "upon is called")

        task.uponSuccess(executor) { _ in expectation.fulfill() }
        task.uponFailure(executor, impossible)

        d.succeed(1)

        waitForExpectations()
        assertExecutorCalledAtLeastOnce()
    }

    func testUponFailure() {
        let d = Deferred<Task<Int>.Result>()
        let task = Task(d, cancellation: {})
        let expectation = self.expectation(description: "upon is called")

        task.uponSuccess(executor, impossible)
        task.uponFailure(executor) { _ in expectation.fulfill() }

        d.fail(Error.first)

        waitForExpectations()
        assertExecutorCalledAtLeastOnce()
    }

    func testThatThrowingMapSubstitutesWithError() {
        let beforeExpectation = expectation(description: "original task filled")
        let beforeTask: Task<Int> = Task(value: -1)

        let afterExpectation = expectation(description: "mapped filled with error")
        let afterTask: Task<String> = beforeTask.map(upon: executor) { _ in
            throw Error.second
        }

        beforeTask.upon(executor) {
            XCTAssertEqual($0.value, -1)
            beforeExpectation.fulfill()
        }

        afterTask.upon(executor) {
            XCTAssertEqual($0.error as? Error, .second)
            afterExpectation.fulfill()
        }

        waitForExpectations()
        assertExecutorCalled(3)
    }

    func testThatFlatMapForwardsCancellationToSubsequentTask() {
        let beforeTask = Task<Int>(value: 1)

        let afterExpectation = expectation(description: "flatMapped task is cancelled")
        let afterTask: Task<String> = beforeTask.flatMap(upon: executor) { _ in
            return Task(Future(), cancellation: afterExpectation.fulfill)
        }

        afterTask.cancel()

        waitForExpectations()
        assertExecutorCalled(1)
    }

    func testThatThrowingFlatMapSubstitutesWithError() {
        let beforeTask = Task<Int>(value: 1)

        let afterExpectation = expectation(description: "flatMapped task is cancelled")
        let afterTask = beforeTask.flatMap(upon: executor) { _ -> Task<String> in
            throw Error.second
        }

        afterTask.uponFailure {
            XCTAssertEqual($0 as? Error, .second)
            afterExpectation.fulfill()
        }

        waitForExpectations()
        assertExecutorCalledAtLeastOnce()
    }

    func testThatRecoverMapsFailures() {
        let beforeExpectation = expectation(description: "original task filled")
        let beforeTask: Task<Int> = Task(error: Error.first)

        let afterExpectation = expectation(description: "mapped filled with same error")
        let afterTask: Task<Int> = beforeTask.recover(upon: executor) { _ in 42 }

        beforeTask.upon {
            XCTAssertEqual($0.error as? Error, .first)
            beforeExpectation.fulfill()
        }

        afterTask.upon {
            XCTAssertEqual($0.value, 42)
            afterExpectation.fulfill()
        }

        waitForExpectations()
        assertExecutorCalled(1)
    }

}

class TaskCustomQueueTests: CustomQueueTestCase {

    func testUponSuccess() {
        let d = Deferred<Task<Int>.Result>()
        let task = Task(d, cancellation: {})
        let expectation = self.expectation(description: "upon is called")

        task.uponSuccess(queue) { _ in
            self.assertOnQueue()
            expectation.fulfill()
        }
        task.uponFailure(queue, impossible)

        d.succeed(1)

        waitForExpectations()
    }

    func testUponFailure() {
        let d = Deferred<Task<Int>.Result>()
        let task = Task(d, cancellation: {})
        let expectation = self.expectation(description: "upon is called")

        task.uponSuccess(queue, impossible)
        task.uponFailure(queue) { _ in
            self.assertOnQueue()
            expectation.fulfill()
        }

        d.fail(Error.first)

        waitForExpectations()
    }

    func testThatThrowingMapSubstitutesWithError() {
        let beforeExpectation = expectation(description: "original task filled")
        let beforeTask: Task<Int> = Task(value: -1)

        let afterExpectation = expectation(description: "mapped filled with error")
        let afterTask: Task<String> = beforeTask.map(upon: queue) { _ in
            self.assertOnQueue()
            throw Error.second
        }

        beforeTask.upon {
            XCTAssertEqual($0.value, -1)
            beforeExpectation.fulfill()
        }

        afterTask.upon {
            XCTAssertEqual($0.error as? Error, .second)
            afterExpectation.fulfill()
        }

        waitForExpectations()
    }

    func testThatFlatMapForwardsCancellationToSubsequentTask() {
        let beforeTask = Task<Int>(value: 1)

        let afterExpectation = expectation(description: "flatMapped task is cancelled")
        let afterTask = beforeTask.flatMap(upon: queue) { _ -> Task<String> in
            self.assertOnQueue()
            return Task(Future(), cancellation: afterExpectation.fulfill)
        }

        afterTask.cancel()

        waitForExpectations()
    }

    func testThatThrowingFlatMapSubstitutesWithError() {
        let beforeTask = Task<Int>(value: 1)

        let afterExpectation = expectation(description: "flatMapped task is cancelled")
        let afterTask = beforeTask.flatMap(upon: queue) { _ -> Task<String> in
            throw Error.second
        }

        afterTask.uponFailure {
            XCTAssertEqual($0 as? Error, .second)
            afterExpectation.fulfill()
        }

        waitForExpectations()
    }

    func testThatRecoverMapsFailures() {
        let beforeExpectation = expectation(description: "original task filled")
        let beforeTask: Task<Int> = Task(error: Error.first)

        let afterExpectation = expectation(description: "mapped filled with same error")
        let afterTask: Task<Int> = beforeTask.recover(upon: queue) { _ in
            self.assertOnQueue()
            return 42
        }

        beforeTask.upon {
            XCTAssertEqual($0.error as? Error, .first)
            beforeExpectation.fulfill()
        }

        afterTask.upon {
            XCTAssertEqual($0.value, 42)
            afterExpectation.fulfill()
        }

        waitForExpectations()
    }

}
