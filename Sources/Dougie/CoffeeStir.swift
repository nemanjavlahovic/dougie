import AppKit
import QuartzCore

/// Soft ribbons of reflected coffee color, rotated in the liquid's perspective.
@MainActor
final class CoffeeStir: CALayer {
    private let flow = CALayer()

    init(surfaceSize: CGSize) {
        super.init()
        bounds = CGRect(origin: .zero, size: surfaceSize)
        opacity = 0
        let diameter = surfaceSize.width
        let plane = CALayer()
        plane.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        plane.position = CGPoint(x: bounds.midX, y: bounds.midY)
        plane.setAffineTransform(CGAffineTransform(scaleX: 1, y: surfaceSize.height / diameter))
        addSublayer(plane)
        flow.frame = plane.bounds
        plane.addSublayer(flow)

        for phase in [-1.8, 1.0] {
            let ribbon = CAGradientLayer()
            ribbon.frame = flow.bounds
            ribbon.colors = [
                NSColor.clear.cgColor,
                NSColor(srgbRed: 0.62, green: 0.34, blue: 0.14, alpha: 0.26).cgColor,
                NSColor(srgbRed: 0.43, green: 0.21, blue: 0.075, alpha: 0.16).cgColor,
                NSColor.clear.cgColor
            ]
            ribbon.locations = [0, 0.3, 0.65, 1]
            ribbon.startPoint = CGPoint(x: 0.1, y: 0.15)
            ribbon.endPoint = CGPoint(x: 0.9, y: 0.85)
            let mask = CAShapeLayer()
            mask.path = ribbonPath(diameter: diameter, phase: phase)
            ribbon.mask = mask
            flow.addSublayer(ribbon)
        }
    }

    override init(layer: Any) { super.init(layer: layer) }
    required init?(coder: NSCoder) { nil }

    func play(clockwise: Bool, reduceMotion: Bool) {
        let fromOpacity = presentation()?.opacity ?? opacity
        let transform = (flow.presentation() ?? flow).transform
        let fromAngle = atan2(transform.m12, transform.m11)
        stop()
        let duration = reduceMotion ? 0.3 : 2.2
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = reduceMotion ? [max(fromOpacity, 0.35), 0] : [fromOpacity, 1, 0.8, 0]
        fade.keyTimes = reduceMotion ? [0, 1] : [0, 0.12, 0.45, 1]
        fade.duration = duration
        add(fade, forKey: "stirFade")
        guard !reduceMotion else { return }

        let toAngle = fromAngle + (clockwise ? 0.95 : -0.95)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        flow.setAffineTransform(CGAffineTransform(rotationAngle: toAngle))
        CATransaction.commit()
        let turn = CABasicAnimation(keyPath: "transform.rotation.z")
        turn.fromValue = fromAngle
        turn.toValue = toAngle
        turn.duration = duration
        turn.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 0.65, 0.3, 1)
        flow.add(turn, forKey: "stirTurn")
    }

    func stop() {
        removeAllAnimations()
        flow.removeAllAnimations()
    }

    private func ribbonPath(diameter: CGFloat, phase: CGFloat) -> CGPath {
        var outside: [CGPoint] = []
        var inside: [CGPoint] = []
        for step in 0...48 {
            let t = CGFloat(step) / 48
            let angle = phase + t * 3.7
            let radius = diameter * (0.07 + 0.28 * t)
            let dx = diameter * 0.28 * cos(angle) - radius * 3.7 * sin(angle)
            let dy = diameter * 0.28 * sin(angle) + radius * 3.7 * cos(angle)
            let width = diameter * 0.018 * pow(sin(.pi * t), 0.8)
            let length = hypot(dx, dy)
            let center = CGPoint(x: diameter * 0.5 + radius * cos(angle), y: diameter * 0.48 + radius * sin(angle))
            outside.append(CGPoint(x: center.x - dy / length * width, y: center.y + dx / length * width))
            inside.append(CGPoint(x: center.x + dy / length * width, y: center.y - dx / length * width))
        }
        let path = CGMutablePath()
        path.addLines(between: outside + inside.reversed())
        path.closeSubpath()
        return path
    }
}
