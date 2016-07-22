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
  public struct DrawingOptions : OptionSet {
    public var rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let reverseDrawingOrder        = DrawingOptions(rawValue: 1 << 0)
    public static let drawPolygonEdges           = DrawingOptions(rawValue: 1 << 1)
    public static let drawStructureEdges         = DrawingOptions(rawValue: 1 << 2)
    public static let replacePolygonsWithCircles = DrawingOptions(rawValue: 1 << 3)
  }

  public struct ColorOptions : OptionSet {
    public var rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let colorInPolygons         = ColorOptions(rawValue: 1 << 0)
    public static let useRandomColors         = ColorOptions(rawValue: 1 << 1)
    public static let usePolygonColorForEdges = ColorOptions(rawValue: 1 << 2)
  }

  // Representation value related properties.
  @IBInspectable
  public var layers: Int = 1 {
    didSet { layers = max(1, layers) }
  }

  @IBInspectable
  public var scale: CGFloat = 1.0 {
    didSet { scale = max(0.001, scale) }
  }

  @IBInspectable
  public var structureEdgeCount: Int = 3 {
    didSet { structureEdgeCount = max(3, structureEdgeCount) }
  }

  @IBInspectable
  public var polygonEdgeCount: Int = 3 {
    didSet { polygonEdgeCount = max(3, polygonEdgeCount) }
  }

  // Option related properties.
  public var drawingOptions: DrawingOptions = [.drawPolygonEdges]
  public var colorOptions = ColorOptions()

  // Color related properties.
  @IBInspectable
  public var innerColor: UIColor = UIColor.clear()
  @IBInspectable
  public var outerColor: UIColor = UIColor.clear()

  // Returns the center coordinate of `self`'s own coordinate space.
  private var boundsCenter: CGPoint {
    return CGPoint(x: bounds.midX, y: bounds.midY)
  }

  private var polygonCornerDistance: CGFloat {
    return min(bounds.width, bounds.height) * scale / CGFloat(layers) / 2.0
  }

  public override func draw(_ rect: CGRect) {
    let layerNumbers: [Int] = {
      if drawingOptions.contains(.reverseDrawingOrder) {
        return Array(stride(from: 0, to: layers, by: 1))
      } else {
        return stride(from: 0, to: layers, by: 1).reversed()
      }
    }()

    // Tracks if the previous layer was even drawn.
    var previousLayerWasDrawn = true

    for layer in layerNumbers {
      // If the previous layer wasn't drawn (and the drawing order isn't
      // reversed), no future layers will be drawn, so `draw(_:)` is completed.
      guard !drawingOptions.contains(.reverseDrawingOrder) &&
        previousLayerWasDrawn else { return }

      // Gets the corner points for the structural shape of the layers.
      let structureCorners: [CGPoint]
      do {
        structureCorners = try CGPoint.cornerPointsForRegularPolygon(
          withEdgeCount: structureEdgeCount,
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

      previousLayerWasDrawn = drawLayer(layer, polygonCenters: polygonCenters)

      if drawingOptions.contains(.drawStructureEdges) {
        do {
          try UIBezierPath.polygon(fromPoints: structureCorners).stroke()
        } catch {
          fatalError("Can't return from error: \(error)")
        }
      }
    }
  }

  /// Draws all of the things that should be drawn for the given `layer`.
  ///
  /// Aside from the passed parameters, this takes into account
  /// * `polygonEdgeCount`
  /// * `drawingOptions`
  /// * `colorOptions`
  /// * `polygonCornerDistance` (and therefore `layers`)
  ///
  /// - Returns: `true` if at least one polygon in the given `layer` was drawn.
  @discardableResult
  private func drawLayer(_ layer: Int, polygonCenters: [CGPoint]) -> Bool {
    // Determines if there is a specific color for this layer, and if there is
    // what it is.
    let specificLayerColor: UIColor? = {
      if colorOptions.contains(.colorInPolygons) &&
        !colorOptions.contains(.useRandomColors) {
        return layerSpecificColor(layer: layer)
      } else {
        return nil
      }
    }()

    // Tracks if at least one polygon was drawn for the given `layer`.
    var drewAPolygon = false

    // Loop that draws each polygon in the `layer`.
    for polygonCenter in polygonCenters {
      // Test if the given `polygonCenter` will produce a polygon that would
      // even lie within the view's coordinate space.
      let pathRectSize = CGSize(
        width: polygonCornerDistance,
        height: polygonCornerDistance
      )
      // Produces a square `CGRect` that could perfectly hold the polygon that
      // will be constructed.
      let pathRect = CGRect(center: polygonCenter, size: pathRectSize)

      // If the `pathRect` doesn't intersect the view's `bounds`, will not be
      // visible and can be skipped in the drawing process.
      guard pathRect.intersects(bounds) else { continue }

      // If this point is reached a polygon will be drawn.
      drewAPolygon = true

      // Gets the path of each polygon (changing center on each iteration).
      // If `drawingOptions` contains `.replacePolygonsWithCircles` cirlce paths
      // will be constructed instead.
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
            edgeCount: polygonEdgeCount,
            center: polygonCenter,
            cornerDistance: polygonCornerDistance
          )
        } catch {
          fatalError("Can't return from error: \(error)")
        }
      }

      // Possibly fills in the color of the polygon dependent on the
      // `colorOptions`.
      if colorOptions.contains(.colorInPolygons) {
        // If there is a `specificLayerColor`, `colorOptions` can't contain
        // `.useRandomColors`.
        (specificLayerColor ?? UIColor.random()).set()
        polygonPath.fill()
      }

      // Possibly draws the edges of the polygon dependent on the
      // `drawingOptions`.
      if drawingOptions.contains(.drawPolygonEdges) {
        if !colorOptions.contains(.usePolygonColorForEdges) {
          UIColor.black().set()
        }
        polygonPath.stroke()
      }
    }

    return drewAPolygon
  }

  /// Calculates the specific color that will be applied to each polygon in a
  /// given `layer`.
  /// This calculation in not only based on the parameter `layer`, but also
  /// takes `layers`, `innerColor` and `outerColor` into account.
  private func layerSpecificColor(layer: Int) -> UIColor {
    // Returns one of the colors if they are equal.
    guard innerColor != outerColor else { return innerColor }

    // Calculates the ratio between the portion of `innerColor` and `outerColor`
    // that should go into the returned color for the given `layer`.
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

extension CGRect {
  /// An initializer that works like `init(origin:size:)` but calculates
  /// `origin` form `center` and `size`.
  internal init(center: CGPoint, size: CGSize) {
    origin = CGPoint(
      x: center.x - size.width  / 2,
      y: center.y - size.height / 2
    )
    self.size = size
  }
}

extension UIColor {
  /// Returns a random color.
  internal static func random() -> UIColor {
    // Generates three random numbers between 0 and 1.
    let hue        = CGFloat(arc4random() % 256) / 256.0
    let saturation = CGFloat(arc4random() % 256) / 256.0
    let brightness = CGFloat(arc4random() % 256) / 256.0
    let alpha      = CGFloat(arc4random() % 256) / 256.0

    // Constructs and returns a `UIColor` from the random numbers.
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
  internal var hsbaComponents: [CGFloat] {
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

