//
//  Model.swift
//  GeometryView
//
//  Created by Marcus Rossel on 14.07.16.
//  Copyright © 2016 Marcus Rossel. All rights reserved.
//

import UIKit

/// A struct describing a two-dimensional line with a starting end an end point.
internal struct Line {
  internal enum ConnectionError : ErrorProtocol {
    case noPoints
    case singlePoint(CGPoint)
  }

  internal enum SegmentationError : ErrorProtocol {
    case invalidNumberOfSegments(Int)
  }

  /// Returns an array of `Line`s connecting all of the `points` in order.
  internal static func linesConsecutivelyConnecting(
    points: [CGPoint]
  ) throws -> [Line] {
    guard !points.isEmpty else { throw ConnectionError.noPoints }
    guard points.count > 1 else {
      throw ConnectionError.singlePoint(points.first!)
    }

    guard points.count > 2 else {
      return [Line(start: points.first!, end: points.last!)]
    }

    // Shifts the `points` so that the last point moves to the `startIndex`.
    var shiftedPoints = points
    shiftedPoints.append(shiftedPoints.removeFirst())

    // The `zip` creates pairs of a point and its successor.
    let pointPairs = zip(points, shiftedPoints)

    // Returns an array of `Line`s constructed from the `pointPairs`.
    return pointPairs.map(Line.init)
  }

  internal var start: CGPoint
  internal var vector: CGVector

  internal var end: CGPoint {
    return start + vector
  }

  /// Returns an array containing the points that segment `self` into the given
  /// `numberOfSegments`.
  internal func segmented(numberOfSegments: Int) throws -> [CGPoint] {
    guard numberOfSegments > 0 else {
      throw SegmentationError.invalidNumberOfSegments(numberOfSegments)
    }

    guard numberOfSegments > 1 else { return [] }

    // Creates an array of `CGFloat`s holding the incremental fractions
    // discribed by `n / numberOfSegments where n < numberOfSegments`.
    let mulitpliers = (1..<numberOfSegments).map { segment in
      return CGFloat(segment) / CGFloat(numberOfSegments)
    }

    // Creates an array of points by incrementally adding a fraction of `vector`
    // to `start`.
    return mulitpliers.map { return start + ($0 * vector) }
  }

  internal init(start: CGPoint, vector: CGVector) {
    self.start = start
    self.vector = vector
  }

  internal init(start: CGPoint, end: CGPoint) {
    self.start = start
    vector = CGVector(dx: end.x - start.x, dy: end.y - start.y)
  }
}

extension Line : Equatable { }
internal func ==(lhs: Line, rhs: Line) -> Bool {
  return (lhs.start, lhs.vector) == (rhs.start, rhs.vector)
}

// Vector operation
internal func + (point: CGPoint, vector: CGVector) -> CGPoint {
  return CGPoint(x: point.x + vector.dx, y: point.y + vector.dy)
}

// Vector operation
internal func * (multiplier: CGFloat, vector: CGVector) -> CGVector {
  return CGVector(dx: multiplier * vector.dx, dy: multiplier * vector.dy)
}

extension CGPoint {
  enum PolygonConstructionError : ErrorProtocol {
    case invalidSideCount(Int)
    case invalidCornerDistance(CGFloat)
  }

  /// Returns an array of points holding the coordinates for the corners of a
  /// homogenous polygon with `sideCount` sides.
  static func cornerPointsForRegularPolygon(
    withSideCount sideCount: Int,
    center: CGPoint,
    cornerDistance distance: CGFloat
  ) throws -> [CGPoint] {
    guard sideCount > 2 else {
      throw CGPoint.PolygonConstructionError.invalidSideCount(sideCount)
    }
    guard distance > 0 else {
      throw CGPoint.PolygonConstructionError.invalidCornerDistance(distance)
    }

    // Calculates the angle needed to construct the polygon iteratively.
    let modifier = (CGFloat(sideCount) - 2) / CGFloat(sideCount)
    let insideAngle = CGFloat.pi - (CGFloat.pi * modifier)

    // Constructs an array of `CGFloat`s incrementally describing the angles for
    // reaching each corner point of the polygon.
    let angles = (1...sideCount).map { side in
      return insideAngle * CGFloat(side)
    }

    // Constructs an array of `CGPoints` describing the corner points of the
    // polygon by using the incremental `angles` and adding a vector of length
    // `distance` to `center`.
    let points = angles.map { angle -> CGPoint in
      let x = distance * sin(angle) + center.x
      let y = distance * cos(angle) + center.y

      return CGPoint(x: x, y: y)
    }

    return points
  }
}

extension UIBezierPath {
  internal enum PolygonConstructionError : ErrorProtocol {
    case noPoint
    case tooFewPoints([CGPoint])
  }

  /// Returns a `UIBezierPath` that connects all of the given `points` in s
  /// closed fashion.
  internal static func polygon(
    fromPoints points: [CGPoint]
  ) throws -> UIBezierPath {
    guard points.count > 0 else { throw UIBezierPath.PolygonConstructionError.noPoint }
    guard points.count > 2 else {
      throw UIBezierPath.PolygonConstructionError.tooFewPoints(points)
    }

    var points = points
    let path = UIBezierPath()

    path.move(to: points.first!)
    points.insert(points.removeFirst(), at: points.endIndex)
    points.forEach { path.addLine(to: $0) }

    return path
  }

  /// Returns a `UIBezierPath` forming a regular polygon with the given
  /// properties.
  internal static func regularPolygon(
    sideCount: Int,
    center: CGPoint,
    sideLength: CGFloat
  ) throws -> UIBezierPath {
    // Returns a circle if `sideCount` is `1`.
    guard sideCount != 1 else {
      return UIBezierPath(
        arcCenter: center,
        radius: sideLength,
        startAngle: 0,
        endAngle: 2 * CGFloat.pi,
        clockwise: false
      )
    }

    // Gets the polygon's corner points.
    let points = try CGPoint.cornerPointsForRegularPolygon(
      withSideCount: sideCount,
      center: center,
      cornerDistance: sideLength
    )
    let polygonPath = UIBezierPath()

    // Moves to the last point and then starts iterating through all of them.
    polygonPath.move(to: points.last!)
    points.forEach { polygonPath.addLine(to: $0) }

    return polygonPath
  }
}
