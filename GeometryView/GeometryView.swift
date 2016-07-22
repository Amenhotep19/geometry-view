//
//  GeometryView.swift
//  GeometryView
//
//  Created by Marcus Rossel on 14.07.16.
//  Copyright © 2016 Marcus Rossel. All rights reserved.
//

import UIKit

@IBDesignable
public class GeometryView : UIView {
  struct DrawingOptions : OptionSet {
    var rawValue: Int
    static let reverseDrawingOrder        = DrawingOptions(rawValue: 1 << 0)
    static let drawPolygonEdges           = DrawingOptions(rawValue: 1 << 1)
    static let drawStructureEdges         = DrawingOptions(rawValue: 1 << 2)
    static let replacePolygonsWithCircles = DrawingOptions(rawValue: 1 << 3)
  }

  struct ColorOptions : OptionSet {
    var rawValue: Int
    static let colorInPolygons         = ColorOptions(rawValue: 1 << 0)
    static let useRandomColors         = ColorOptions(rawValue: 1 << 1)
    static let usePolygonColorForEdges = ColorOptions(rawValue: 1 << 2)
  }

  // Representation value related properties.
  @IBInspectable
  var layers: Int = 1 {
    didSet { layers = max(1, layers) }
  }

  @IBInspectable
  var zoom: CGFloat = 1.0 {
    didSet { zoom = max(0.0, zoom) }
  }

  @IBInspectable
  var structureSideCount: Int = 3 {
    didSet { structureSideCount = max(3, structureSideCount) }
  }

  @IBInspectable
  var polygonSideCount: Int = 3 {
    didSet { polygonSideCount = max(3, polygonSideCount) }
  }

  // Option related properties.
  var drawingOptions: DrawingOptions = [.drawPolygonEdges]
  var colorOptions = ColorOptions()

  // Color related properties.
  @IBInspectable
  var innerColor: UIColor = UIColor.clear()
  @IBInspectable
  var outerColor: UIColor = UIColor.clear()

  // Returns the center coordinate of `self`'s own coordinate space.
  var boundsCenter: CGPoint {
    return CGPoint(x: bounds.midX, y: bounds.midY)
  }

  // Returns the length of the shorter side of the current `UIScreen`.
  var shorterScreenLength: CGFloat {
    let screenBounds = UIScreen.main().bounds
    return min(screenBounds.width, screenBounds.height)
  }

  var polygonCornerDistance: CGFloat {
    return shorterScreenLength * zoom / CGFloat(layers) / 2.0
  }

  public override func draw(_ rect: CGRect) {
    let layerNumbers: [Int] = {
      if drawingOptions.contains(.reverseDrawingOrder) {
        return Array(stride(from: 0, to: layers, by: 1))
      } else {
        return stride(from: 0, to: layers, by: 1).reversed()
      }
    }()

    for layer in layerNumbers {
      // Gets the corner points for the structural shape of the layers.
      let structureCorners: [CGPoint]
      do {
        structureCorners = try CGPoint.cornerPointsForRegularPolygon(
          withSideCount: structureSideCount,
          center: boundsCenter,
          cornerDistance: CGFloat(layer) * polygonCornerDistance
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

      if drawingOptions.contains(.drawStructureEdges) {
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
      if colorOptions.contains(.colorInPolygons) &&
        !colorOptions.contains(.useRandomColors) {
        return layerSpecificColor(layer: layer)
      } else {
        return nil
      }
    }()

    // Loop that draws each polygon in the `layer`.
    for polygonCenter in polygonCenters {
      /*TODO-BEGIN*/
      // Detect if polygon in the screen's coordinate space. In that case don't even draw it.
      /*TODO-END*/

      // Gets the path of each polygon (changing center on each iteration).
      let polygonPath: UIBezierPath
      if drawingOptions.contains(.replacePolygonsWithCircles) {
        polygonPath = UIBezierPath(
          arcCenter: polygonCenter,
          radius: polygonCornerDistance,
          startAngle: 0,
          endAngle: 2.0 * CGFloat.pi,
          clockwise: false
        )
      } else {
        do {
          polygonPath = try UIBezierPath.regularPolygon(
            sideCount: polygonSideCount,
            center: polygonCenter,
            cornerDistance: polygonCornerDistance
          )
        } catch {
          fatalError("Can't return from error: \(error)")
        }
      }

      // Possibly fills in the color of the polygon dependent on the
      // specifications.
      if colorOptions.contains(.colorInPolygons) {
        if colorOptions.contains(.useRandomColors) {
          UIColor.random().set()
        } else {
          specificLayerColor!.set()
        }

        polygonPath.fill()
      }

      // Possibly draws the edges of the polygon.
      if drawingOptions.contains(.drawPolygonEdges) {
        if !colorOptions.contains(.usePolygonColorForEdges) {
          UIColor.black().set()
        }
        polygonPath.stroke()
      }
    }
  }

  private func layerSpecificColor(layer: Int) -> UIColor {
    // Returns one of the colors if they are equal.
    guard innerColor != outerColor else { return innerColor }

    let layerFactor = layers != 1 ? CGFloat(layer) / CGFloat(layers - 1) : 0

    // Constructs an array of color components mixed proportionally from
    // `innerColor` and `outerColor` to fit the current `layer`.
    let components = zip(innerColor.hsbaComponents, outerColor.hsbaComponents)
    let layerColorComponents = components.map { inner, outer -> CGFloat in
      let (smaller, larger) = inner < outer ? (inner, outer) : (outer, inner)
      return smaller + (layerFactor * (larger - smaller))
    }

    // Constructs a new `UIColor` from the mixed `layorColorComponents`.
    return UIColor(
      hue:        layerColorComponents[0],
      saturation: layerColorComponents[1],
      brightness: layerColorComponents[2],
      alpha:      layerColorComponents[3]
    )
  }
}

extension UIColor {
  /// Returns a random color.
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

  /// Returns an array of `CGFloat`s containing four elements with `self`'s:
  /// * hue (index `0`)
  /// * saturation (index `1`)
  /// * brightness (index `2`)
  /// * alpha (index `3`)
  var hsbaComponents: [CGFloat] {
    // Constructs the array in which to store the HSBA-components.
    var components = [CGFloat](repeating: 0.0, count: 4)

    // Stores `self`'s HSBA-component values in `components`.
    getHue(       &(components[0]),
      saturation: &(components[1]),
      brightness: &(components[2]),
      alpha:      &(components[3])
    )

    return components
  }
}

