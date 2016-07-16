//
//  GeometryViewTests.swift
//  GeometryViewTests
//
//  Created by Marcus Rossel on 14.07.16.
//  Copyright © 2016 Marcus Rossel. All rights reserved.
//

import XCTest
@testable import GeometryView

class GeometryViewTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Put setup code here. This method is called before the invocation of each
    // test method in the class.
  }

  func testLineInitilization() {
    let startPoint = CGPoint(x: 0, y: 0)

    let line1 = Line(start: startPoint, end: CGPoint(x: 100, y: 100))
    let line2 = Line(start: startPoint, vector: CGVector(dx: 100, dy: 100))

    XCTAssertEqual(line1, line2)
  }

  func testConsecutivelyConnectingPoints() {
    let point1 = CGPoint(x: 01, y: 01)
    let point2 = CGPoint(x: 00, y: 50)
    let point3 = CGPoint(x: 33, y: 15)
    let point4 = CGPoint(x: 13, y: 18)

    let twoPoints = [point1, point2]
    let fourPoints = [point1, point2, point3, point4]

    do {
      let _ = try Line.linesConsecutivelyConnecting(points: [])
    } catch Line.ConnectionError.noPoints {
      // Continue.
    } catch {
      XCTFail("Should have thrown error `LineConnectionError.noPoints`")
    }

    do {
      let _ = try Line.linesConsecutivelyConnecting(points: [point1])
    } catch Line.ConnectionError.singlePoint(let point) {
      XCTAssertEqual(point, point1)
    } catch {
      XCTFail("Should have thrown error `LineConnectionError.singlePoint`")
    }

    let lines1 = try? Line.linesConsecutivelyConnecting(points: twoPoints)
    XCTAssertNotNil(lines1, "No error should have been thrown.")
    XCTAssertEqual(lines1!, [Line(start: point1, end: point2)])

    let lines2 = try? Line.linesConsecutivelyConnecting(points: fourPoints)
    XCTAssertNotNil(lines2, "No error should have been thrown.")

    let desiredResult = [
      Line(start: point1, end: point2),
      Line(start: point2, end: point3),
      Line(start: point3, end: point4),
      Line(start: point4, end: point1),
    ]
    XCTAssertEqual(lines2!, desiredResult)
  }

  func testSegmentingLine() {
    let start = CGPoint(x: 0, y: 0)
    let end = CGPoint(x: 100, y: 100)
    let line = Line(start: start, end: end)

    do {
      let _ = try line.segmented(numberOfSegments: 1)
    } catch Line.SegmentationError.invalidNumberOfSegments(let number) {
      XCTAssertEqual(number, 1)
    } catch {
      XCTFail("Should have thrown error `SegmentationError.invalidNumberOfSegments`")
    }

    let points = try? line.segmented(numberOfSegments: 4)
    XCTAssertNotNil(points, "No error should have been thrown.")

    let desiredResult = [
      CGPoint(x: 25, y: 25),
      CGPoint(x: 50, y: 50),
      CGPoint(x: 75, y: 75),
    ]
    XCTAssertEqual(points!, desiredResult)
  }
}






