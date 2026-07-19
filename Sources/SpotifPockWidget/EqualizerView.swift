import AppKit

public class EqualizerView: NSView {
    private let barCount = 7
    private var bars: [CALayer] = []
    private var timer: Timer?
    private var phase: CGFloat = 0
    // smoothing state
    private var currentRatios: [CGFloat] = []
    private var targetRatios: [CGFloat] = []
    private var currentColors: [NSColor] = []
    /// 0..1 lerp factor per tick (higher = snappier, lower = smoother)
    public var smoothingFactor: CGFloat = 0.22
    /// amplitude multiplier for the bar heights
    public var sensitivity: CGFloat = 1.0 {
        didSet { sensitivity = max(0.1, min(4.0, sensitivity)) }
    }
    /// speed multiplier affecting tick frequency and phase increment
    public var speed: CGFloat = 1.0 {
        didSet {
            if speed <= 0 { speed = 1.0 }
            restartTimerIfNeeded()
        }
    }
    /// animation duration in seconds for bar height transitions
    public var animationDuration: CGFloat = 0.12 {
        didSet {
            if animationDuration <= 0 { animationDuration = 0.12 }
        }
    }

    public var style: EqualizerStyle = .bars {
        didSet {
            layoutBarFrames()
            updateBars(animated: false)
        }
    }

    public var accentColor: NSColor = .systemGreen {
        didSet {
            updateBars(animated: false)
        }
    }

    public var ambientColors: [NSColor] = [] {
        didSet {
            updateBars(animated: false)
        }
    }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupBars()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupBars()
    }

    deinit {
        timer?.invalidate()
    }

    private func setupBars() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        currentRatios = Array(repeating: 0.2, count: barCount)
        targetRatios = Array(repeating: 0.2, count: barCount)
        currentColors = Array(repeating: accentColor, count: barCount)

        for i in 0..<barCount {
            let bar = CALayer()
            bar.backgroundColor = accentColor.cgColor
            bar.anchorPoint = CGPoint(x: 0.5, y: 0.0)
            layer?.addSublayer(bar)
            bars.append(bar)
            // stagger initial targets for a more organic start
            targetRatios[i] = animatedHeightRatio(for: i)
            currentRatios[i] = targetRatios[i]
        }
    }

    public override func layout() {
        super.layout()
        layoutBarFrames()
    }

    private func layoutBarFrames() {
        guard layer != nil, bounds.width > 0, bounds.height > 0 else { return }
        let gap = bounds.width / CGFloat(barCount * 7)
        let barWidth = (bounds.width - gap * CGFloat(barCount - 1)) / CGFloat(barCount)

        for (index, bar) in bars.enumerated() {
            let x = CGFloat(index) * (barWidth + gap)
            let idleHeight = idleHeight(for: index)
            bar.cornerRadius = cornerRadius(for: barWidth)
            bar.frame = CGRect(x: x, y: 0, width: barWidth, height: idleHeight)
        }
    }

    public func startAnimation() {
        guard timer == nil else { return }
        updateBars(animated: false)
        scheduleTimer()
    }

    private func scheduleTimer() {
        // base tick 0.06s, scale by 1/speed
        let interval = TimeInterval(0.06 / max(0.1, speed))
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.phase += 0.45 * self.speed
            for i in 0..<self.barCount {
                // apply sensitivity to animated ratio targets
                let base = self.animatedHeightRatio(for: i)
                self.targetRatios[i] = min(1.0, base * self.sensitivity)
            }
            self.updateBars(animated: true)
        }
    }

    private func restartTimerIfNeeded() {
        guard timer != nil else { return }
        timer?.invalidate()
        timer = nil
        scheduleTimer()
    }

    public func stopAnimation() {
        timer?.invalidate()
        timer = nil
        updateBars(animated: true, targetHeightRatio: 0.2)
    }

    private func updateBars(animated: Bool, targetHeightRatio: CGFloat? = nil) {
        guard !bars.isEmpty, bounds.height > 0 else { return }
        CATransaction.begin()
        CATransaction.setAnimationDuration(animated ? Double(animationDuration) : 0.0)

        for (index, bar) in bars.enumerated() {
            // determine target ratio
            let newTarget = targetHeightRatio ?? targetRatios[index]
            // smooth current ratio towards target
            let current = currentRatios[index]
            let lerp = smoothingFactor
            let next = current + (newTarget - current) * lerp
            currentRatios[index] = next

            let height = max(bounds.height * 0.14, bounds.height * next)
            let x = bar.frame.origin.x
            let y = yOrigin(for: height)
            bar.frame = CGRect(x: x, y: y, width: bar.frame.width, height: height)
            bar.cornerRadius = cornerRadius(for: bar.frame.width)
            bar.opacity = opacity(for: index)

            // color smoothing
            let targetColor = color(for: index)
            let prev = currentColors[index]

            func rgbaComponents(_ c: NSColor) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                if let converted = c.usingColorSpace(.deviceRGB) {
                    converted.getRed(&r, green: &g, blue: &b, alpha: &a)
                    return (r, g, b, a)
                }
                // fallback to accentColor components
                if let conv2 = accentColor.usingColorSpace(.deviceRGB) {
                    conv2.getRed(&r, green: &g, blue: &b, alpha: &a)
                    return (r, g, b, a)
                }
                return (0, 0, 0, 1)
            }

            let p = rgbaComponents(prev)
            let t = rgbaComponents(targetColor)
            let blended = NSColor(red: p.r + (t.r - p.r) * lerp,
                                  green: p.g + (t.g - p.g) * lerp,
                                  blue: p.b + (t.b - p.b) * lerp,
                                  alpha: p.a + (t.a - p.a) * lerp)
            currentColors[index] = blended
            bar.backgroundColor = blended.cgColor
        }

        CATransaction.commit()
    }

    private func color(for index: Int) -> NSColor {
        guard !ambientColors.isEmpty else { return accentColor }
        return ambientColors[index % ambientColors.count]
    }

    private func idleHeight(for index: Int) -> CGFloat {
        switch style {
        case .bars:
            return bounds.height * 0.2
        case .wave:
            return bounds.height * (0.25 + CGFloat(index).truncatingRemainder(dividingBy: 3) * 0.08)
        case .dots:
            return max(4, min(bounds.height * 0.28, bounds.width / CGFloat(barCount)))
        }
    }

    private func animatedHeightRatio(for index: Int) -> CGFloat {
        switch style {
        case .bars:
            return CGFloat.random(in: 0.22...0.92)
        case .wave:
            let sine = sin(phase + CGFloat(index) * 0.75)
            return 0.22 + ((sine + 1) / 2) * 0.68
        case .dots:
            return CGFloat.random(in: 0.18...0.75)
        }
    }

    private func yOrigin(for height: CGFloat) -> CGFloat {
        switch style {
        case .bars, .wave:
            return 0
        case .dots:
            return max(0, (bounds.height - height) / 2)
        }
    }

    private func cornerRadius(for width: CGFloat) -> CGFloat {
        switch style {
        case .bars, .wave:
            return min(2.5, width / 2)
        case .dots:
            return width / 2
        }
    }

    private func opacity(for index: Int) -> Float {
        switch style {
        case .bars:
            return Float(0.58 + Double(index) * 0.045)
        case .wave:
            return 0.85
        case .dots:
            return 0.75
        }
    }
}
