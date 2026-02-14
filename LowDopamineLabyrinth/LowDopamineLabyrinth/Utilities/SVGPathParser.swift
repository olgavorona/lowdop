import SwiftUI

struct SVGPathParser {
    static func parse(_ svgPath: String, scale: CGFloat = 1.0, offset: CGPoint = .zero) -> Path {
        var path = Path()
        let tokens = tokenize(svgPath)
        var i = 0
        var currentPoint = CGPoint.zero

        while i < tokens.count {
            let token = tokens[i]
            switch token {
            case "M":
                guard i + 2 < tokens.count,
                      let x = Double(tokens[i + 1]),
                      let y = Double(tokens[i + 2]) else { i += 1; continue }
                let point = CGPoint(x: CGFloat(x) * scale + offset.x,
                                    y: CGFloat(y) * scale + offset.y)
                path.move(to: point)
                currentPoint = point
                i += 3

            case "L":
                guard i + 2 < tokens.count,
                      let x = Double(tokens[i + 1]),
                      let y = Double(tokens[i + 2]) else { i += 1; continue }
                let point = CGPoint(x: CGFloat(x) * scale + offset.x,
                                    y: CGFloat(y) * scale + offset.y)
                path.addLine(to: point)
                currentPoint = point
                i += 3

            case "Q":
                guard i + 4 < tokens.count,
                      let cx = Double(tokens[i + 1]),
                      let cy = Double(tokens[i + 2]),
                      let x = Double(tokens[i + 3]),
                      let y = Double(tokens[i + 4]) else { i += 1; continue }
                let control = CGPoint(x: CGFloat(cx) * scale + offset.x,
                                      y: CGFloat(cy) * scale + offset.y)
                let end = CGPoint(x: CGFloat(x) * scale + offset.x,
                                  y: CGFloat(y) * scale + offset.y)
                path.addQuadCurve(to: end, control: control)
                currentPoint = end
                i += 5

            case "C":
                guard i + 6 < tokens.count,
                      let c1x = Double(tokens[i + 1]),
                      let c1y = Double(tokens[i + 2]),
                      let c2x = Double(tokens[i + 3]),
                      let c2y = Double(tokens[i + 4]),
                      let x = Double(tokens[i + 5]),
                      let y = Double(tokens[i + 6]) else { i += 1; continue }
                let c1 = CGPoint(x: CGFloat(c1x) * scale + offset.x,
                                 y: CGFloat(c1y) * scale + offset.y)
                let c2 = CGPoint(x: CGFloat(c2x) * scale + offset.x,
                                 y: CGFloat(c2y) * scale + offset.y)
                let end = CGPoint(x: CGFloat(x) * scale + offset.x,
                                  y: CGFloat(y) * scale + offset.y)
                path.addCurve(to: end, control1: c1, control2: c2)
                currentPoint = end
                i += 7

            case "Z", "z":
                path.closeSubpath()
                i += 1

            default:
                i += 1
            }
        }
        return path
    }

    static func parseToPoints(_ svgPath: String, scale: CGFloat = 1.0, offset: CGPoint = .zero) -> [CGPoint] {
        var points: [CGPoint] = []
        let tokens = tokenize(svgPath)
        var i = 0

        while i < tokens.count {
            let token = tokens[i]
            switch token {
            case "M", "L":
                guard i + 2 < tokens.count,
                      let x = Double(tokens[i + 1]),
                      let y = Double(tokens[i + 2]) else { i += 1; continue }
                points.append(CGPoint(x: CGFloat(x) * scale + offset.x,
                                      y: CGFloat(y) * scale + offset.y))
                i += 3
            case "Q":
                guard i + 4 < tokens.count,
                      let x = Double(tokens[i + 3]),
                      let y = Double(tokens[i + 4]) else { i += 1; continue }
                points.append(CGPoint(x: CGFloat(x) * scale + offset.x,
                                      y: CGFloat(y) * scale + offset.y))
                i += 5
            default:
                i += 1
            }
        }
        return points
    }

    private static func tokenize(_ svgPath: String) -> [String] {
        var tokens: [String] = []
        var current = ""

        for char in svgPath {
            if char.isLetter {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                tokens.append(String(char))
            } else if char == " " || char == "," {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty {
            tokens.append(current)
        }
        return tokens
    }
}
