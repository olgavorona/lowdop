import CoreGraphics

struct DrawingValidator {
    let segments: [SegmentData]
    let tolerance: CGFloat
    let scale: CGFloat
    let offset: CGPoint

    func isPointOnPath(_ point: CGPoint) -> Bool {
        let minDist = minimumDistance(to: point)
        return minDist <= tolerance
    }

    func minimumDistance(to point: CGPoint) -> CGFloat {
        var minDist: CGFloat = .greatestFiniteMagnitude
        for segment in segments {
            let a = CGPoint(x: CGFloat(segment.start.x) * scale + offset.x,
                            y: CGFloat(segment.start.y) * scale + offset.y)
            let b = CGPoint(x: CGFloat(segment.end.x) * scale + offset.x,
                            y: CGFloat(segment.end.y) * scale + offset.y)
            let dist = pointToSegmentDistance(point, a, b)
            minDist = min(minDist, dist)
        }
        return minDist
    }

    func isNearEnd(_ point: CGPoint, endPoint: PointData, radius: CGFloat = 30) -> Bool {
        let end = CGPoint(x: CGFloat(endPoint.x) * scale + offset.x,
                          y: CGFloat(endPoint.y) * scale + offset.y)
        let dx = point.x - end.x
        let dy = point.y - end.y
        return sqrt(dx * dx + dy * dy) <= radius
    }

    private func pointToSegmentDistance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lengthSq = dx * dx + dy * dy

        if lengthSq == 0 {
            let ddx = p.x - a.x
            let ddy = p.y - a.y
            return sqrt(ddx * ddx + ddy * ddy)
        }

        var t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSq
        t = max(0, min(1, t))

        let projX = a.x + t * dx
        let projY = a.y + t * dy
        let ddx = p.x - projX
        let ddy = p.y - projY
        return sqrt(ddx * ddx + ddy * ddy)
    }
}
