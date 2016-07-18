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
  let point0 = CGPoint.zero
  let point1 = CGPoint(x: 01, y: 01)
  let point2 = CGPoint(x: 00, y: 20)
  let point3 = CGPoint(x: 33, y: 00)
  let point4 = CGPoint(x: 40, y: 44)

  let squareCornerPoints = [
    CGPoint(x: 0,   y: -50),
    CGPoint(x: 50,  y: 0),
    CGPoint(x: 0,   y: 50),
    CGPoint(x: -50, y: 0),
  ]

  override func setUp() {
    super.setUp()
    // Put setup code here. This method is called before the invocation of each
    // test method in the class.
  }

  func testLineInitilization() {
    let line1 = Line(start: point1, end: CGPoint(x: 100, y: 100))
    let line2 = Line(start: point1, vector: CGVector(dx: 100, dy: 100))

    XCTAssertEqual(line1, line2)
  }

  func testConsecutivelyConnectingPoints() {
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
      Line(start: point4, end: point1)
    ]
    XCTAssertEqual(lines2!, desiredResult)
  }

  func testSegmentingLine() {
    let line = Line(start: point0, end: CGPoint(x: 100, y: 100))

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
      CGPoint(x: 75, y: 75)
    ]
    XCTAssertEqual(points!, desiredResult)
  }

  func testCornerPointsForRegularPolygon() {
    do {
      let _ = try CGPoint.cornerPointsForRegularPolygon(
        withSideCount: 0,
        center: point0,
        cornerDistance: 10
      )
    } catch CGPoint.PolygonConstructionError.invalidSideCount(let count) {
      XCTAssertEqual(count, 0)
    } catch {
      XCTFail("Should have thrown error `PolygonConstructionError.invalidSideCount`")
    }

    do {
      let _ = try CGPoint.cornerPointsForRegularPolygon(
        withSideCount: 3,
        center: point0,
        cornerDistance: 0
      )
    } catch CGPoint.PolygonConstructionError.invalidCornerDistance(let distance) {
      XCTAssertEqual(distance, 0)
    } catch {
      XCTFail("Should have thrown error `PolygonConstructionError.invalidCornerDistance`")
    }

    let points = try? CGPoint.cornerPointsForRegularPolygon(
      withSideCount: 4,
      center: point0,
      cornerDistance: 50
    )
    XCTAssertNotNil(points)
    XCTAssertEqual(points!, squareCornerPoints)
  }

  func testPolygonFromPoints() {
    do {
      let _ = try UIBezierPath.polygon(fromPoints: [])
    } catch UIBezierPath.PolygonConstructionError.noPoint {
      // Continue.
    } catch {
      XCTFail("Should have thrown error `PolygonConstructionError.noPoint`")
    }

    do {
      let _ = try UIBezierPath.polygon(fromPoints: [point1, point3])
    } catch UIBezierPath.PolygonConstructionError.tooFewPoints(let points) {
      XCTAssertEqual(points, [point1, point3])
    } catch {
      XCTFail("Should have thrown error `PolygonConstructionError.tooFewPoints`")
    }

    let path = try? UIBezierPath.polygon(fromPoints: squareCornerPoints)
    XCTAssertNotNil(path)

    XCTAssertEqual(path!.currentPoint, squareCornerPoints[0])
    XCTAssertTrue(path!.contains(squareCornerPoints[1]))
    XCTAssertTrue(path!.contains(squareCornerPoints[2]))
    XCTAssertTrue(path!.contains(squareCornerPoints[3]))
  }

  func testRegularPolygon() {
    do {
      let _ = try UIBezierPath.regularPolygon(
        sideCount: 2,
        center: point0,
        sideLength: 10
      )
    } catch CGPoint.PolygonConstructionError.invalidSideCount(let count) {
      XCTAssertEqual(count, 2)
    } catch {
      XCTFail("Should have thrown error `PolygonConstructionError.invalidSideCount`")
    }

    do {
      let _ = try UIBezierPath.regularPolygon(
        sideCount: 4,
        center: point0,
        sideLength: -23
      )
    } catch CGPoint.PolygonConstructionError.invalidCornerDistance(let distance) {
      XCTAssertEqual(distance, -23)
    } catch {
      XCTFail("Should have thrown error `PolygonConstructionError.invalidCornerDistance`")
    }

    let path = try? UIBezierPath.regularPolygon(
      sideCount: 4,
      center: point0,
      sideLength: 50
    )
    XCTAssertNotNil(path)

    XCTAssertEqual(path!.currentPoint, squareCornerPoints[0])
    XCTAssertTrue(path!.contains(squareCornerPoints[1]))
    XCTAssertTrue(path!.contains(squareCornerPoints[2]))
    XCTAssertTrue(path!.contains(squareCornerPoints[3]))
  }
}
