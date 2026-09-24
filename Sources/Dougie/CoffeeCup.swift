import AppKit
import DougieCore
import QuartzCore
import SwiftUI

/// A photographic cup with a separate, clipped coffee surface. Only Core Animation
/// interpolates frames; SwiftUI updates this view when session or visibility changes.
struct CoffeeCup: NSViewRepresentable {
    let timeline: AwakeTimeline?
    let isVisible: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeNSView(context: Context) -> CoffeeCupView { CoffeeCupView() }

    func updateNSView(_ view: CoffeeCupView, context: Context) {
        view.setState(timeline: timeline, visible: isVisible, reduceMotion: reduceMotion)
    }

    static func dismantleNSView(_ view: CoffeeCupView, coordinator: ()) {
        view.stopAnimations()
    }
}

@MainActor
final class CoffeeCupView: NSView {
    private let artwork = CALayer()
    private let photograph = CALayer()
    private let opening = CALayer()
    private let coffee = CAGradientLayer()
    private let sheen = CAGradientLayer()
    private let crema = CAShapeLayer()
    private let reflection = CAShapeLayer()
    private let swirl = CoffeeStir(surfaceSize: CGSize(width: 658, height: 281))
    private let steam = CALayer()
    private var wisps: [CALayer] = []
    private var timeline: AwakeTimeline?
    private var visible = false
    private var reduceMotion = false
    private var levelTimer: Timer?

    // Coordinates are registered to the original 1254 × 1254 artwork. The coffee
    // rises behind the fixed mouth; its lower edge is occluded by the front wall.
    private let emptyY: CGFloat = 630
    private let fullY: CGFloat = 402
    private let apertureBounds = CGRect(x: 291, y: 239, width: 661, height: 285)

    override var isFlipped: Bool { true }

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.addSublayer(artwork)
        artwork.bounds = CGRect(x: 0, y: 0, width: 1254, height: 1254)
        artwork.anchorPoint = .zero
        photograph.frame = artwork.bounds
        photograph.contentsGravity = .resizeAspect
        let url = Bundle.main.url(forResource: "lludix-cup", withExtension: "png")
            ?? Bundle.module.url(forResource: "lludix-cup", withExtension: "png")
        if let url, let image = NSImage(contentsOf: url) {
            photograph.contents = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }
        artwork.addSublayer(photograph)

        opening.frame = artwork.bounds
        let aperture = CAShapeLayer()
        aperture.path = CGPath(ellipseIn: apertureBounds, transform: nil)
        aperture.fillColor = NSColor.black.cgColor
        opening.mask = aperture
        artwork.addSublayer(opening)

        coffee.bounds = CGRect(x: 0, y: 0, width: 658, height: 281)
        coffee.position = CGPoint(x: 621, y: emptyY)
        coffee.colors = [
            NSColor(srgbRed: 0.08, green: 0.04, blue: 0.025, alpha: 1).cgColor,
            NSColor(srgbRed: 0.22, green: 0.115, blue: 0.055, alpha: 1).cgColor,
            NSColor(srgbRed: 0.115, green: 0.055, blue: 0.025, alpha: 1).cgColor
        ]
        coffee.locations = [0, 0.65, 1]
        coffee.startPoint = CGPoint(x: 0.35, y: 0)
        coffee.endPoint = CGPoint(x: 0.65, y: 1)
        let surfaceMask = CAShapeLayer()
        surfaceMask.path = CGPath(ellipseIn: coffee.bounds, transform: nil)
        coffee.mask = surfaceMask
        coffee.opacity = 0
        opening.addSublayer(coffee)

        sheen.frame = coffee.bounds
        sheen.type = .radial
        sheen.colors = [
            NSColor(srgbRed: 0.67, green: 0.40, blue: 0.18, alpha: 0.19).cgColor,
            NSColor(srgbRed: 0.40, green: 0.22, blue: 0.09, alpha: 0).cgColor
        ]
        sheen.startPoint = CGPoint(x: 0.24, y: 0.32)
        sheen.endPoint = CGPoint(x: 0.91, y: 0.95)
        coffee.addSublayer(sheen)

        crema.path = CGPath(ellipseIn: coffee.bounds.insetBy(dx: 4, dy: 3), transform: nil)
        crema.fillColor = nil
        crema.strokeColor = NSColor(srgbRed: 0.66, green: 0.39, blue: 0.16, alpha: 0.8).cgColor
        crema.lineWidth = 5
        coffee.addSublayer(crema)

        let glint = CGMutablePath()
        glint.move(to: CGPoint(x: 73, y: 91))
        glint.addCurve(to: CGPoint(x: 257, y: 34), control1: CGPoint(x: 110, y: 52), control2: CGPoint(x: 194, y: 37))
        reflection.path = glint
        reflection.fillColor = nil
        reflection.strokeColor = NSColor(srgbRed: 0.97, green: 0.88, blue: 0.70, alpha: 0.48).cgColor
        reflection.lineWidth = 2
        reflection.lineCap = .round
        coffee.addSublayer(reflection)
        swirl.frame = coffee.bounds
        coffee.addSublayer(swirl)

        steam.frame = artwork.bounds
        let steamFade = CAGradientLayer()
        steamFade.frame = artwork.bounds
        steamFade.colors = [NSColor.clear.cgColor, NSColor.black.cgColor, NSColor.black.cgColor, NSColor.clear.cgColor]
        steamFade.locations = [0.10, 0.15, 0.22, 0.28]
        steam.mask = steamFade
        for x in [530.0, 618.0, 699.0] {
            let wisp = CALayer()
            wisp.frame = artwork.bounds
            // Feathered strokes give the vapor a soft edge without a live blur filter.
            for (width, alpha) in [(24.0, 0.045), (13.0, 0.10), (5.0, 0.25)] {
                let stroke = CAShapeLayer()
                stroke.path = steamPath(x: x, bend: 0)
                stroke.fillColor = nil
                stroke.strokeColor = NSColor(srgbRed: 0.64, green: 0.61, blue: 0.57, alpha: alpha).cgColor
                stroke.lineWidth = width
                stroke.lineCap = .round
                wisp.addSublayer(stroke)
            }
            steam.addSublayer(wisp)
            wisps.append(wisp)
        }
        steam.opacity = 0
        artwork.addSublayer(steam)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Coffee surface")
        setAccessibilityIdentifier("coffee-surface")
        setAccessibilityHelp("Press to gently stir the coffee.")
        focusRingType = .exterior
    }

    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { (timeline?.remainingFraction() ?? 0) > 0 }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func isAccessibilityEnabled() -> Bool { acceptsFirstResponder }

    override func mouseDown(with event: NSEvent) {
        focusRingType = .none
        noteFocusRingMaskChanged()
        if !stir(at: convert(event.locationInWindow, from: nil)) {
            super.mouseDown(with: event)
        }
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { focusRingType = .exterior }
        return accepted
    }

    override func keyDown(with event: NSEvent) {
        if !event.isARepeat, event.keyCode == 49 || event.keyCode == 36 {
            focusRingType = .exterior
            _ = accessibilityPerformPress()
        } else {
            super.keyDown(with: event)
        }
    }

    override func accessibilityPerformPress() -> Bool {
        guard let layer else { return false }
        let surface = (coffee.presentation() ?? coffee).frame.intersection(apertureBounds)
        guard !surface.isNull else { return false }
        let point = CGPoint(x: surface.midX, y: surface.midY)
        return stir(at: layer.convert(point, from: artwork))
    }

    override var focusRingMaskBounds: NSRect {
        layer?.convert(apertureBounds, from: artwork) ?? .zero
    }

    override func drawFocusRingMask() {
        NSBezierPath(ovalIn: focusRingMaskBounds).fill()
    }

    /// Hit-test both masks using the displayed level, which may be mid-refill.
    @discardableResult
    func stir(at point: CGPoint) -> Bool {
        guard visible, windowIsVisible, acceptsFirstResponder, let layer else { return false }
        let surface = coffee.presentation() ?? coffee
        guard surface.opacity > 0.05 else { return false }
        let inArtwork = artwork.convert(point, from: layer)
        guard CGPath(ellipseIn: apertureBounds, transform: nil).contains(inArtwork) else { return false }
        let inCoffee = CGPoint(x: inArtwork.x - surface.frame.minX, y: inArtwork.y - surface.frame.minY)
        guard CGPath(ellipseIn: coffee.bounds, transform: nil).contains(inCoffee) else { return false }

        let clockwise = inCoffee.x >= coffee.bounds.midX
        swirl.play(clockwise: clockwise, reduceMotion: reduceMotion)
        if !reduceMotion { curlSteam(clockwise: clockwise) }
        return true
    }

    private func curlSteam(clockwise: Bool) {
        let from = (steam.presentation() ?? steam).transform.m41
        let curl = CAKeyframeAnimation(keyPath: "transform.translation.x")
        curl.values = [from, clockwise ? 18 : -18, clockwise ? 5 : -5, 0]
        curl.keyTimes = [0, 0.3, 0.65, 1]
        curl.duration = 2.2
        curl.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: 3)
        steam.add(curl, forKey: "stirSteam")
    }

    override func layout() {
        super.layout()
        let scale = min(bounds.width / 1150, bounds.height / 1030)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        artwork.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        artwork.position = CGPoint(x: (bounds.width - 1150 * scale) / 2 - 50 * scale, y: -110 * scale)
        let screenScale = window?.backingScaleFactor ?? 2
        for sublayer in [photograph, crema, reflection] + wisps.flatMap({ $0.sublayers ?? [] }) {
            sublayer.contentsScale = screenScale
        }
        CATransaction.commit()
    }

    func setState(timeline newTimeline: AwakeTimeline?, visible newVisible: Bool, reduceMotion newReduceMotion: Bool) {
        let changed = timeline != newTimeline
        let appeared = !visible && newVisible
        let accessibilityChanged = reduceMotion != newReduceMotion
        timeline = newTimeline
        visible = newVisible
        reduceMotion = newReduceMotion
        toolTip = acceptsFirstResponder ? "Click to gently stir the coffee." : nil
        guard changed || appeared || accessibilityChanged || !visible else { return }
        // Only a new session refills. Reopening restores the level from its clock.
        let animate = changed && visible && windowIsVisible && !appeared && !reduceMotion
        transition(animated: animate)
    }

    private func transition(animated: Bool) {
        let fromPosition = coffee.presentation()?.position ?? coffee.position
        let fromOpacity = coffee.presentation()?.opacity ?? coffee.opacity
        let fromSteam = steam.presentation()?.opacity ?? steam.opacity
        stopAnimations()
        let now = Date.now
        let fraction = timeline?.remainingFraction(at: now) ?? 0
        let active = fraction > 0
        let destination = position(for: fraction)
        let steamOpacity = Float(min(1, fraction * 5))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        coffee.position = destination
        coffee.opacity = active ? 1 : 0
        steam.opacity = steamOpacity
        CATransaction.commit()
        guard visible, windowIsVisible else { return }
        if reduceMotion {
            // Keep meaningful timer progress, without interpolating or looping motion.
            if active, timeline?.endsAt != nil {
                let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
                    Task { @MainActor [weak self] in self?.transition(animated: false) }
                }
                timer.tolerance = 2
                levelTimer = timer
                RunLoop.main.add(timer, forMode: .common)
            }
            return
        }
        startAmbientMotion(after: animated && active ? 1.8 : 0)

        if active, let timeline, let end = timeline.endsAt {
            let remaining = end.timeIntervalSince(now)
            let refill = animated ? min(1.8, remaining) : 0
            var positions = [NSValue(point: animated ? fromPosition : destination)]
            var times: [NSNumber] = [0]
            if refill > 0, refill < remaining {
                positions.append(NSValue(point: position(for: timeline.remainingFraction(at: now.addingTimeInterval(refill)))))
                times.append(NSNumber(value: refill / remaining))
            }
            positions.append(NSValue(point: position(for: 0)))
            times.append(1)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            coffee.position = position(for: 0)
            coffee.opacity = 0
            steam.opacity = 0
            CATransaction.commit()
            let drain = CAKeyframeAnimation(keyPath: "position")
            drain.values = positions
            drain.keyTimes = times
            drain.duration = remaining
            drain.timingFunctions = positions.count == 3
                ? [CAMediaTimingFunction(controlPoints: 0.22, 0.65, 0.28, 1), CAMediaTimingFunction(name: .linear)]
                : [CAMediaTimingFunction(name: .linear)]
            coffee.add(drain, forKey: "sessionLevel")
            animateTimedOpacity(coffee, from: animated ? fromOpacity : 1, to: 1,
                                rise: animated ? 0.25 : 0, fade: 0.65, remaining: remaining)
            animateTimedOpacity(steam, from: animated ? fromSteam : steamOpacity, to: steamOpacity,
                                rise: refill, fade: end.timeIntervalSince(timeline.startedAt) * 0.2, remaining: remaining)
            return
        }
        guard animated else { return }

        let duration = active ? 1.8 : 0.65
        animate(coffee, key: "position", from: NSValue(point: fromPosition), to: NSValue(point: destination), duration: duration)
        animate(coffee, key: "opacity", from: fromOpacity, to: coffee.opacity, duration: active ? 0.25 : duration)
        animate(steam, key: "opacity", from: fromSteam, to: steam.opacity, duration: duration)
    }

    private func position(for fraction: Double) -> CGPoint {
        CGPoint(x: 621, y: emptyY + (fullY - emptyY) * fraction)
    }

    private func animateTimedOpacity(_ layer: CALayer, from: Float, to peak: Float,
                                     rise: TimeInterval, fade: TimeInterval, remaining: TimeInterval) {
        var values = [from]
        var times: [NSNumber] = [0]
        let riseEnd = min(rise, remaining)
        if riseEnd > 0, riseEnd < remaining {
            values.append(peak)
            times.append(NSNumber(value: riseEnd / remaining))
        }
        let fadeStart = max(riseEnd, remaining - fade)
        if fadeStart > riseEnd, fadeStart < remaining {
            values.append(peak)
            times.append(NSNumber(value: fadeStart / remaining))
        }
        values.append(0)
        times.append(1)
        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.values = values
        animation.keyTimes = times
        animation.duration = remaining
        layer.add(animation, forKey: "sessionOpacity")
    }

    private func steamPath(x: CGFloat, bend: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x, y: 333))
        path.addCurve(to: CGPoint(x: x - 9 + bend, y: 247),
                      control1: CGPoint(x: x + 23, y: 303), control2: CGPoint(x: x - 30 + bend, y: 283))
        path.addCurve(to: CGPoint(x: x + 8 - bend, y: 154),
                      control1: CGPoint(x: x + 20 + bend, y: 210), control2: CGPoint(x: x - 20 - bend, y: 188))
        return path
    }

    private var windowIsVisible: Bool {
        window?.isVisible == true && window?.occlusionState.contains(.visible) == true
    }

    private func startAmbientMotion(after delay: TimeInterval = 0) {
        guard (timeline?.remainingFraction() ?? 0) > 0, visible, windowIsVisible, !reduceMotion,
              sheen.animation(forKey: "surfaceDrift") == nil else { return }

        let drift = CABasicAnimation(keyPath: "startPoint")
        drift.fromValue = NSValue(point: sheen.startPoint)
        drift.toValue = NSValue(point: CGPoint(x: 0.66, y: 0.53))
        drift.duration = 4.8
        drift.autoreverses = true
        repeatAnimation(drift, on: sheen, key: "surfaceDrift", after: delay)

        let ripple = CAKeyframeAnimation(keyPath: "transform.translation.y")
        ripple.values = [0, -5, 3, 0]
        ripple.keyTimes = [0, 0.35, 0.7, 1]
        ripple.duration = 7.2
        repeatAnimation(ripple, on: reflection, key: "surfaceRipple", after: delay)

        for (index, wisp) in wisps.enumerated() {
            let duration = 6.4 + Double(index) * 0.8
            let rise = CABasicAnimation(keyPath: "transform.translation.y")
            rise.fromValue = 18
            rise.toValue = -34
            rise.duration = duration
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [0, 0.7, 1, 0.55, 0]
            fade.keyTimes = [0, 0.18, 0.45, 0.72, 1]
            fade.duration = duration
            let breath = CAAnimationGroup()
            breath.animations = [rise, fade]
            breath.duration = duration
            breath.timeOffset = Double(index) * 2.1
            repeatAnimation(breath, on: wisp, key: "steamRise", after: delay)

            for stroke in wisp.sublayers ?? [] {
                let curl = CABasicAnimation(keyPath: "path")
                curl.fromValue = (stroke as? CAShapeLayer)?.path
                curl.toValue = steamPath(x: [530.0, 618.0, 699.0][index], bend: index == 1 ? -24 : 24)
                curl.duration = duration / 2
                curl.autoreverses = true
                repeatAnimation(curl, on: stroke, key: "steamCurl", after: delay)
            }
        }
    }

    private func repeatAnimation(_ animation: CAAnimation, on layer: CALayer, key: String, after delay: TimeInterval) {
        animation.repeatCount = .greatestFiniteMagnitude
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.beginTime = layer.convertTime(CACurrentMediaTime(), from: nil) + delay
        animation.fillMode = .backwards
        layer.add(animation, forKey: key)
    }

    private func animate(_ layer: CALayer, key: String, from: Any, to: Any, duration: TimeInterval) {
        let animation = CABasicAnimation(keyPath: key)
        animation.fromValue = from
        animation.toValue = to
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 0.65, 0.28, 1)
        layer.add(animation, forKey: key)
    }

    func stopAnimations() {
        levelTimer?.invalidate()
        levelTimer = nil
        swirl.stop()
        for animatedLayer in [coffee, sheen, reflection, steam] + wisps + wisps.flatMap({ $0.sublayers ?? [] }) {
            animatedLayer.removeAllAnimations()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self, name: NSWindow.didChangeOcclusionStateNotification, object: nil)
        if let window {
            NotificationCenter.default.addObserver(self, selector: #selector(windowVisibilityChanged),
                                                   name: NSWindow.didChangeOcclusionStateNotification, object: window)
        }
        windowVisibilityChanged()
    }

    @objc private func windowVisibilityChanged() {
        // MenuBarExtra can retain its content while its window is ordered out.
        // Check AppKit visibility as well as SwiftUI's appearance lifecycle.
        if windowIsVisible { transition(animated: false) } else { stopAnimations() }
    }
}
