//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Metrics API open source project
//
// Copyright (c) 2018-2019 Apple Inc. and the Swift Metrics API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Metrics API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import CoreMetrics
@testable import Metrics
import XCTest

class MetricsExtensionsTests: XCTestCase {
    func testTimerBlock() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        // run the test
        let name = "timer-\(NSUUID().uuidString)"
        let delay = 0.05
        Timer.measure(label: name) {
            Thread.sleep(forTimeInterval: delay)
        }
        let timer = metrics.timers[name] as! TestTimer
        XCTAssertEqual(1, timer.values.count, "expected number of entries to match")
        XCTAssertGreaterThan(timer.values[0].1, Int64(delay * 1_000_000_000), "expected delay to match")
    }

    func testTimerWithTimeInterval() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        // run the test
        let timer = Timer(label: "test-timer")
        let testTimer = timer.handler as! TestTimer
        let timeInterval = TimeInterval(Double.random(in: 1 ... 500))
        timer.record(timeInterval)
        XCTAssertEqual(1, testTimer.values.count, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[0].1, Int64(timeInterval * 1_000_000_000), "expected value to match")
    }

    func testTimerWithDispatchTime() throws {
        // bootstrap with our test metrics
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)
        // run the test
        let timer = Timer(label: "test-timer")
        let testTimer = timer.handler as! TestTimer
        // nano
        let nano = DispatchTimeInterval.nanoseconds(Int.random(in: 1 ... 500))
        timer.record(nano)
        XCTAssertEqual(testTimer.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(Int(testTimer.values[0].1), nano.nano(), "expected value to match")
        // micro
        let micro = DispatchTimeInterval.microseconds(Int.random(in: 1 ... 500))
        timer.record(micro)
        XCTAssertEqual(testTimer.values.count, 2, "expected number of entries to match")
        XCTAssertEqual(Int(testTimer.values[1].1), micro.nano(), "expected value to match")
        // milli
        let milli = DispatchTimeInterval.milliseconds(Int.random(in: 1 ... 500))
        timer.record(milli)
        XCTAssertEqual(testTimer.values.count, 3, "expected number of entries to match")
        XCTAssertEqual(Int(testTimer.values[2].1), milli.nano(), "expected value to match")
        // seconds
        let sec = DispatchTimeInterval.seconds(Int.random(in: 1 ... 500))
        timer.record(sec)
        XCTAssertEqual(testTimer.values.count, 4, "expected number of entries to match")
        XCTAssertEqual(Int(testTimer.values[3].1), sec.nano(), "expected value to match")
        // never
        timer.record(DispatchTimeInterval.never)
        XCTAssertEqual(testTimer.values.count, 5, "expected number of entries to match")
        XCTAssertEqual(testTimer.values[4].1, 0, "expected value to match")
    }

    func testTimerWithDispatchTimeInterval() {
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)

        let name = "timer-\(UUID().uuidString)"

        let timer = Timer(label: name)
        let start = DispatchTime.now()
        let end = DispatchTime(uptimeNanoseconds: start.uptimeNanoseconds + 1000 * 1000 * 1000)
        timer.recordInterval(since: start, end: end)

        let testTimer = timer.handler as! TestTimer
        XCTAssertEqual(testTimer.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(UInt64(testTimer.values.first!.1), end.uptimeNanoseconds - start.uptimeNanoseconds, "expected value to match")
        XCTAssertEqual(metrics.timers.count, 1, "timer should have been stored")
    }

    func testTimerUnits() throws {
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)

        let name = "timer-\(NSUUID().uuidString)"
        let value = Int64.random(in: 0 ... 1000)

        let timer = Timer(label: name)
        timer.recordNanoseconds(value)

        let testTimer = timer.handler as! TestTimer
        XCTAssertEqual(testTimer.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(testTimer.values.first!.1, value, "expected value to match")
        XCTAssertEqual(metrics.timers.count, 1, "timer should have been stored")

        let secondsName = "timer-seconds-\(NSUUID().uuidString)"
        let secondsValue = Int64.random(in: 0 ... 1000)
        let secondsTimer = Timer(label: secondsName, preferredDisplayUnit: .seconds)
        secondsTimer.recordSeconds(secondsValue)

        let testSecondsTimer = secondsTimer.handler as! TestTimer
        XCTAssertEqual(testSecondsTimer.values.count, 1, "expected number of entries to match")
        XCTAssertEqual(metrics.timers.count, 2, "timer should have been stored")
    }

    func testPreferDisplayUnit() {
        let metrics = TestMetrics()
        MetricsSystem.bootstrapInternal(metrics)

        let value = Double.random(in: 0 ... 1000)
        let timer = Timer(label: "test", preferredDisplayUnit: .seconds)
        timer.recordSeconds(value)

        let testTimer = timer.handler as! TestTimer

        testTimer.preferDisplayUnit(.nanoseconds)
        XCTAssertEqual(testTimer.retrieveValueInPreferredUnit(atIndex: 0), value * 1000 * 1000 * 1000, accuracy: 1.0, "expected value to match")

        testTimer.preferDisplayUnit(.microseconds)
        XCTAssertEqual(testTimer.retrieveValueInPreferredUnit(atIndex: 0), value * 1000 * 1000, accuracy: 0.001, "expected value to match")

        testTimer.preferDisplayUnit(.milliseconds)
        XCTAssertEqual(testTimer.retrieveValueInPreferredUnit(atIndex: 0), value * 1000, accuracy: 0.000001, "expected value to match")

        testTimer.preferDisplayUnit(.seconds)
        XCTAssertEqual(testTimer.retrieveValueInPreferredUnit(atIndex: 0), value, accuracy: 0.000000001, "expected value to match")

        testTimer.preferDisplayUnit(.minutes)
        XCTAssertEqual(testTimer.retrieveValueInPreferredUnit(atIndex: 0), value / 60, accuracy: 0.000000001, "expected value to match")

        testTimer.preferDisplayUnit(.hours)
        XCTAssertEqual(testTimer.retrieveValueInPreferredUnit(atIndex: 0), value / (60 * 60), accuracy: 0.000000001, "expected value to match")

        testTimer.preferDisplayUnit(.days)
        XCTAssertEqual(testTimer.retrieveValueInPreferredUnit(atIndex: 0), value / (60 * 60 * 24), accuracy: 0.000000001, "expected value to match")
    }
}

// https://bugs.swift.org/browse/SR-6310
extension DispatchTimeInterval {
    func nano() -> Int {
        switch self {
        case .nanoseconds(let value):
            return value
        case .microseconds(let value):
            return value * 1000
        case .milliseconds(let value):
            return value * 1_000_000
        case .seconds(let value):
            return value * 1_000_000_000
        case .never:
            return 0
        }
    }
}
