//
//  GeometryView.swift
//  GeometryView
//
//  Created by Marcus Rossel on 14.07.16.
//  Copyright © 2016 Marcus Rossel. All rights reserved.
//

import UIKit

@IBDesignable
public class GeometryView: UIView {
  @IBInspectable
  var layers: Int = 1 {
    didSet { layers = max(1, layers) }
  }

  @IBInspectable
  var polygonSideCount: Int = 1 {
    didSet { polygonSideCount = max(1, polygonSideCount) }
  }

  @IBInspectable
  var structureSideCount: Int = 1 {
    didSet { structureSideCount = max(1, structureSideCount) }
  }

  // Drawing related properties.
  @IBInspectable
  var drawPolygonEdges: Bool = true
  @IBInspectable
  var drawStructureEdges: Bool = false

  // Color related properties.
  @IBInspectable
  var colorInPolygons: Bool = false
  @IBInspectable
  var randomColors: Bool = false
  @IBInspectable
  var innerColor: UIColor = UIColor.clear()
  @IBInspectable
  var outerColor: UIColor = UIColor.clear()

  // Returns the center coordinate of `self`'s own coordinate space.
  var boundsCenter: CGPoint {
    return CGPoint(x: bounds.midX, y: bounds.midY)
  }

  let constant = CGFloat(50)

  public override func draw(_ rect: CGRect) {
    for layer in 0..<layers {
      // Gets the corner points for the structural shape of the layers.
      let structureCorners: [CGPoint]
      do {
        structureCorners = try CGPoint.cornerPointsForRegularPolygon(
          withSideCount: structureSideCount,
          center: boundsCenter,
          cornerDistance: CGFloat(layer) * constant
        )
      } catch CGPoint.PolygonConstructionError.invalidCornerDistance(let distance) {
        // `distance` should only be 0 when `layer` is 0, in which case one
        // polygon should be drawn right at `boundsCenter`.
        if distance == 0 {
          drawLayer(layer, polygonCenters: [boundsCenter])
          continue
        } else {
          fatalError(
            "Can't return from error: `CGPoint.PolygonConstructionError" +
            ".invalidCornerDistance` with a payload smaller than 1."
          )
        }
      } catch {
        fatalError("Can't return from error: \(error)")
      }

      // Creates an array of `Line`s connecting the `structureCorners`.
      let structureEdges: [Line]
      do {
        structureEdges = try Line.linesConsecutivelyConnecting(
          points: structureCorners
        )
      } catch {
        fatalError("Can't return from error: \(error)")
      }

      // Segments each edge `structureEdges` into the `layer`-dependent number
      // of segments. These points will be the centers of the polygons.
      let structureEdgeSegments = structureEdges.map { edge -> [CGPoint] in
        do {
          return try edge.segmented(numberOfSegments: layer)
        } catch {
          fatalError("Can't return from error: \(error)")
        }
      }

      // Fuses the `structureCorners` and `structureEdgeSegments` into one array
      // while putting them into consecutive order.
      let polygonCenters = zip(structureCorners, structureEdgeSegments).map {
        cornerPoint, edgePoint -> [CGPoint] in
        return [cornerPoint] + edgePoint
      }.flatMap { $0 }

      drawLayer(layer, polygonCenters: polygonCenters)

      if drawStructureEdges {
        do {
          try UIBezierPath.polygon(fromPoints: structureCorners).stroke()
        } catch {
          fatalError("Can't return from error: \(error)")
        }
      }
    }
  }

  private func drawLayer(_ layer: Int, polygonCenters: [CGPoint]) {
    // Color precalculations.
    let specificLayerColor: UIColor? = {
      if colorInPolygons && !randomColors {
        return layerSpecificColor(layer: layer)
      } else {
        return nil
      }
    }()

    // Loop that draws each polygon in the `layer`.
    for polygonCenter in polygonCenters {
      // Gets the path of each polygon (changing center on each iteration).
      let polygonPath: UIBezierPath
      do {
        polygonPath = try UIBezierPath.regularPolygon(
          sideCount: polygonSideCount,
          center: polygonCenter,
          sideLength: constant
        )
      } catch {
        fatalError("Can't return from error: \(error)")
      }

      // Possibly draws the edges of the polygon.
      if drawPolygonEdges {
        polygonPath.stroke()
      }

      // Possibly fills in the color of the polygon dependent on the
      // specifications.
      if colorInPolygons {
        (randomColors ? UIColor.random() : specificLayerColor!).set()
        polygonPath.fill()
      }
    }
  }

  private func layerSpecificColor(layer: Int) -> UIColor {
    let layerFactor = CGFloat(layer) / CGFloat(layers)

    // Gets the color components from `innerColor` and `outerColor` and
    // converts them to a `[CGFloat]`.
    let innerCC = innerColor.cgColor.components
    let outerCC = outerColor.cgColor.components
    let innerComponents = Array(UnsafeBufferPointer(start: innerCC, count: 4))
    let outerComponents = Array(UnsafeBufferPointer(start: outerCC, count: 4))

    // Constructs an array of color components mixed proportionally from
    // `innerColor` and `outerColor` to fit the current `layer`.
    let layerColorComponents = zip(innerComponents, outerComponents).map {
      inner, outer -> CGFloat in
      let (smaller, larger) = inner < outer ? (inner, outer) : (outer, inner)
      return smaller + (layerFactor * (larger - smaller))
    }

    // Constructs a new `UIColor` from the mixed `layorColorComponents`.
    return UIColor(
      red:   layerColorComponents[0],
      green: layerColorComponents[1],
      blue:  layerColorComponents[2],
      alpha: layerColorComponents[3]
    )
  }
}

extension UIColor {
  static func random() -> UIColor {
    // Generates three random numbers between 0 and 1.
    let hue        = CGFloat(arc4random() % 256) / 256.0
    let saturation = CGFloat(arc4random() % 256) / 256.0
    let brightness = CGFloat(arc4random() % 256) / 256.0
    let alpha      = CGFloat(arc4random() % 256) / 256.0

    // Constructs a `UIColor` from the random numbers.
    return UIColor(
      hue:        hue,
      saturation: saturation,
      brightness: brightness,
      alpha:      alpha
    )
  }
}

