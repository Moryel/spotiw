import AppKit

public class EqualizerView: NSView {
    /// follows the view width (about one bar per 7 pt), see `layout()`
    private var barCount = 7
    private var bars: [CALayer] = []
    private var timer: Timer?
    private var phase: CGFloat = 0
    // smoothing state
    private var currentRatios: [CGFloat] = []
    private var targetRatios: [CGFloat] = []
    private var currentColors: [RGBA] = []
    private var targetComponents: [RGBA] = [RGBA(.systemGreen)]
    private var colorsSettled = false
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
            paletteDidChange()
            updateBars(animated: false)
        }
    }

    public var ambientColors: [NSColor] = [] {
        didSet {
            paletteDidChange()
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
        rebuildBars()
    }

    private func rebuildBars() {
        bars.forEach { $0.removeFromSuperlayer() }
        bars = []

        currentRatios = Array(repeating: 0.2, count: barCount)
        targetRatios = Array(repeating: 0.2, count: barCount)
        currentColors = Array(repeating: RGBA(accentColor), count: barCount)
        colorsSettled = false

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
        let wanted = max(5, min(160, Int(bounds.width / 7)))
        if wanted != barCount {
            barCount = wanted
            rebuildBars()
        }
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
            bar.opacity = opacity(for: index)
            bar.frame = CGRect(x: x, y: yOrigin(for: idleHeight), width: barWidth, height: idleHeight)
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
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.phase += 0.45 * self.speed
            for i in 0..<self.barCount {
                // random styles pick a new target only once a bar has (nearly) reached the old one,
                // otherwise the bars just jitter around the average height
                let reached = abs(self.currentRatios[i] - self.targetRatios[i]) < 0.06
                guard self.style == .wave || reached else { continue }
                // apply sensitivity to animated ratio targets
                let base = self.animatedHeightRatio(for: i)
                self.targetRatios[i] = min(1.0, base * self.sensitivity)
            }
            self.updateBars(animated: true)
        }
        // .common keeps the bars moving while the menu bar menu is open
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
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

        let lerp = smoothingFactor
        let blendColors = !colorsSettled
        var largestColorStep: CGFloat = 0

        for (index, bar) in bars.enumerated() {
            // determine target ratio
            let newTarget = targetHeightRatio ?? targetRatios[index]
            // smooth current ratio towards target
            let current = currentRatios[index]
            let next = current + (newTarget - current) * lerp
            currentRatios[index] = next

            let height = max(bounds.height * 0.14, bounds.height * next)
            // with many bars, skip sub-pixel changes
            if abs(bar.frame.height - height) > 0.25 {
                bar.frame = CGRect(x: bar.frame.origin.x, y: yOrigin(for: height), width: bar.frame.width, height: height)
            }

            // color smoothing, only until the bars have reached the new palette
            guard blendColors else { continue }
            let p = currentColors[index]
            let t = targetComponents[index % targetComponents.count]
            let blended = RGBA(r: p.r + (t.r - p.r) * lerp,
                               g: p.g + (t.g - p.g) * lerp,
                               b: p.b + (t.b - p.b) * lerp,
                               a: p.a + (t.a - p.a) * lerp)
            largestColorStep = max(largestColorStep, abs(t.r - p.r), abs(t.g - p.g), abs(t.b - p.b), abs(t.a - p.a))
            currentColors[index] = blended
            bar.backgroundColor = CGColor(red: blended.r, green: blended.g, blue: blended.b, alpha: blended.a)
        }

        if blendColors && largestColorStep < 0.004 {
            colorsSettled = true
        }

        CATransaction.commit()
    }

    private struct RGBA {
        var r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat

        init(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
            self.r = r; self.g = g; self.b = b; self.a = a
        }

        init(_ color: NSColor) {
            let rgb = color.usingColorSpace(.deviceRGB) ?? .systemGreen
            self.init(r: rgb.redComponent, g: rgb.greenComponent, b: rgb.blueComponent, a: rgb.alphaComponent)
        }
    }

    private func paletteDidChange() {
        let palette = ambientColors.isEmpty ? [accentColor] : ambientColors
        targetComponents = palette.map(RGBA.init)
        colorsSettled = false
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
            // fades in from left to right whatever the bar count
            return Float(0.58 + 0.27 * Double(index) / Double(max(1, barCount - 1)))
        case .wave:
            return 0.85
        case .dots:
            return 0.75
        }
    }
}
