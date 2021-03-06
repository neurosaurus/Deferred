//
//  FutureCustomExecutorTests.swift
//  Deferred
//
//  Created by Zachary Waldowski on 4/10/16.
//  Copyright © 2016 Big Nerd Ranch. All rights reserved.
//

import XCTest
import Deferred

// Should this be promoted to an initializer on Future?
private func delay<Value>(@autoclosure(escaping) value: Void -> Value, by interval: NSTimeInterval) -> Future<Value> {
    let d = Deferred<Value>()
    afterDelay(interval, upon: Deferred<Value>.genericQueue) {
        d.fill(value())
    }
    return Future(d)
}

class FutureCustomExecutorTests: CustomExecutorTestCase {
    func testUpon() {
        let d = Deferred<Void>()

        let expect = expectationWithDescription("upon block called when deferred is filled")
        d.upon(executor) { _ in
            expect.fulfill()
        }

        d.fill(())

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
        assertExecutorCalled(1)
    }

    func testMap() {
        let marker = Deferred<Void>()
        let testValue = 42
        let mapped = marker.map(upon: executor) { testValue }

        let expect = expectationWithDescription("upon block called when deferred is filled")
        mapped.upon(executor) {
            XCTAssertEqual($0, testValue)
            expect.fulfill()
        }

        marker.fill(())

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
        assertExecutorCalled(2)
    }

    func testFlatMap() {
        let marker = Deferred<Void>()
        let testValue = 42
        let flattened = marker.flatMap(upon: executor) { _ in delay(testValue, by: 0.2) }

        let expect = expectationWithDescription("upon block called when deferred is filled")
        flattened.upon(executor) {
            XCTAssertEqual($0, testValue)
            expect.fulfill()
        }

        marker.fill(())

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
        assertExecutorCalled(3)
    }

}
