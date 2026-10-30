import AppKit

public class MarqueeLabel: NSView {
    private let textField = NSTextField(labelWithString: "")
    private var animationKey = "marqueeAnimation"
    private var laidOutSize: (text: CGFloat, bounds: CGSize)?

    public var stringValue: String {
        get { textField.stringValue }
        set {
            // re-setting the same text must not restart the scroll
            guard newValue != textField.stringValue else { return }
            textField.stringValue = newValue
            laidOutSize = nil
            needsLayout = true
        }
    }

    public var font: NSFont? {
        get { textField.font }
        set {
            textField.font = newValue
            laidOutSize = nil
            needsLayout = true
        }
    }

    public var textColor: NSColor? {
        get { textField.textColor }
        set { textField.textColor = newValue }
    }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        wantsLayer = true
        layer?.masksToBounds = true

        textField.isEditable = false
        textField.isBordered = false
        textField.drawsBackground = false
        textField.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        textField.textColor = NSColor.white
        textField.lineBreakMode = .byClipping
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.wantsLayer = true

        addSubview(textField)
    }

    public override func layout() {
        super.layout()
        layoutTextField()
    }

    private func layoutTextField() {
        let fittingSize = textField.attributedStringValue.boundingRect(
            with: NSSize(width: CGFloat.greatestFiniteMagnitude, height: bounds.height),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).size
        // NSTextField draws with a few points of inner padding
        let textWidth = ceil(fittingSize.width) + 6

        if let previous = laidOutSize, previous.text == textWidth, previous.bounds == bounds.size {
            return
        }
        laidOutSize = (textWidth, bounds.size)

        textField.frame = CGRect(x: 0, y: (bounds.height - fittingSize.height) / 2, width: textWidth, height: fittingSize.height)

        if textWidth > bounds.width {
            startMarquee()
        } else {
            stopMarquee()
            textField.frame.origin.x = 0
        }
    }

    public func startMarqueeIfNeeded() {
        guard textField.frame.width > bounds.width else {
            stopMarquee()
            return
        }
        guard textField.layer?.animation(forKey: animationKey) == nil else { return }
        startMarquee()
    }

    public func startMarquee() {
        stopMarquee()
        guard textField.frame.width > bounds.width else { return }

        let travel = textField.frame.width - bounds.width
        let duration = CFTimeInterval(travel / 30.0) + 1.0

        let animation = CABasicAnimation(keyPath: "position.x")
        animation.fromValue = textField.layer?.position.x ?? 0
        animation.toValue = (textField.layer?.position.x ?? 0) - travel
        animation.duration = duration
        animation.repeatCount = .infinity
        animation.autoreverses = true
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        textField.layer?.add(animation, forKey: animationKey)
    }

    public func stopMarquee() {
        textField.layer?.removeAnimation(forKey: animationKey)
    }
}
