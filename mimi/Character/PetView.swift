import AppKit

final class PetView: NSView {
    private let expressionPresetResolver = ExpressionPresetResolver()
    private let expressionRuntimeState: ExpressionRuntimeState

    var permissionGranted = false {
        didSet {
            needsDisplay = true
        }
    }

    var trackingStatusText = "目标：待验证" {
        didSet {
            needsDisplay = true
        }
    }

    var mappedTargetPoint: CGPoint? {
        didSet {
            needsDisplay = true
        }
    }

    var stateStatusText = "状态：Focus" {
        didSet {
            needsDisplay = true
        }
    }

    var attentionMode: AttentionMode = .typing {
        didSet {
            needsDisplay = true
        }
    }

    var generationPhase: GenerationPhase = .inactive {
        didSet {
            needsDisplay = true
        }
    }

    override var isFlipped: Bool {
        true
    }

    private struct BubbleAppearance {
        let fillColor: NSColor
        let strokeColor: NSColor
        let textColor: NSColor
        let borderWidth: CGFloat
    }

    override init(frame frameRect: NSRect) {
        self.expressionRuntimeState = ExpressionRuntimeState()
        super.init(frame: frameRect)
        configureExpressionRuntimeState()
    }

    init(frame frameRect: NSRect, textProvider: ExpressionTextProvider?) {
        self.expressionRuntimeState = ExpressionRuntimeState(textProvider: textProvider)
        super.init(frame: frameRect)
        configureExpressionRuntimeState()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()

        let preset = resolveExpressionPreset()
        drawTail(using: preset)
        drawFace(using: preset)
        drawSpeechBubble(using: preset)
        drawEyes(using: preset)
        drawStatusBadge()
        drawTrackingBadge()
        drawStateBadge()
        drawAttentionBadge()
        drawMappedTarget()
    }

    private func drawTail(using preset: ExpressionPreset) {
        let tail = NSBezierPath()
        tail.lineWidth = preset.tail.lineWidth
        preset.tail.strokeColor.setStroke()
        tail.move(to: NSPoint(x: 146, y: 136))
        tail.curve(
            to: preset.tail.endPoint,
            controlPoint1: preset.tail.controlPoint1,
            controlPoint2: preset.tail.controlPoint2
        )
        tail.stroke()
    }

    private func drawFace(using preset: ExpressionPreset) {
        let leftEar = NSBezierPath()
        leftEar.move(to: NSPoint(x: 68, y: 78))
        leftEar.line(to: NSPoint(x: preset.ears.leftEarPeakX, y: preset.ears.earTipY))
        leftEar.line(to: NSPoint(x: 116, y: 88))
        leftEar.close()

        let rightEar = NSBezierPath()
        rightEar.move(to: NSPoint(x: 152, y: 88))
        rightEar.line(to: NSPoint(x: preset.ears.rightEarPeakX, y: preset.ears.earTipY))
        rightEar.line(to: NSPoint(x: 104, y: 78))
        rightEar.close()

        let faceRect = NSRect(x: 42, y: 62, width: 136, height: 128)
        let face = NSBezierPath(roundedRect: faceRect, xRadius: 64, yRadius: 64)

        let furColor = NSColor(calibratedRed: 0.88, green: 0.68, blue: 0.42, alpha: 0.95)
        furColor.setFill()
        leftEar.fill()
        rightEar.fill()
        face.fill()

        NSColor(calibratedRed: 0.95, green: 0.84, blue: 0.64, alpha: 0.95).setFill()
        NSBezierPath(ovalIn: NSRect(x: 72, y: 106, width: 76, height: 58)).fill()
    }

    private func drawSpeechBubble(using preset: ExpressionPreset) {
        guard let bubblePresentation = bubblePresentation(for: preset) else {
            return
        }

        let appearance = bubbleAppearance(for: bubblePresentation.style)
        let bubbleRect = NSRect(x: 126, y: 18, width: 70, height: 28)
        let bubble = NSBezierPath(roundedRect: bubbleRect, xRadius: 14, yRadius: 14)
        bubble.lineWidth = appearance.borderWidth
        appearance.fillColor.setFill()
        bubble.fill()
        appearance.strokeColor.setStroke()
        bubble.stroke()

        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: 142, y: 43))
        tail.line(to: NSPoint(x: 132, y: 58))
        tail.line(to: NSPoint(x: 151, y: 48))
        tail.close()
        appearance.fillColor.setFill()
        tail.fill()
        appearance.strokeColor.setStroke()
        tail.lineWidth = max(1, appearance.borderWidth - 0.2)
        tail.stroke()

        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: appearance.textColor,
            .paragraphStyle: style
        ]
        bubblePresentation.text.draw(in: bubbleRect.insetBy(dx: 8, dy: 7), withAttributes: attributes)
    }

    private func drawEyes(using preset: ExpressionPreset) {
        let eyeColor = NSColor.white.withAlphaComponent(0.95)
        let style = preset.eye
        let leftEye = NSBezierPath(ovalIn: style.leftEyeRect)
        let rightEye = NSBezierPath(ovalIn: style.rightEyeRect)
        eyeColor.setFill()
        leftEye.fill()
        rightEye.fill()

        let leftPupilOrigin = pupilOrigin(in: style.leftEyeRect, pupilSize: style.pupilSize, style: style)
        let rightPupilOrigin = pupilOrigin(in: style.rightEyeRect, pupilSize: style.pupilSize, style: style)

        style.pupilColor.setFill()
        NSBezierPath(ovalIn: NSRect(origin: leftPupilOrigin, size: style.pupilSize)).fill()
        NSBezierPath(ovalIn: NSRect(origin: rightPupilOrigin, size: style.pupilSize)).fill()

        drawEyeLids(for: style.leftEyeRect, overlayHeight: style.lidOverlayHeight)
        drawEyeLids(for: style.rightEyeRect, overlayHeight: style.lidOverlayHeight)
        drawEyeSparkles(at: leftPupilOrigin, pupilSize: style.pupilSize, alpha: style.sparkleAlpha)
        drawEyeSparkles(at: rightPupilOrigin, pupilSize: style.pupilSize, alpha: style.sparkleAlpha)
        drawExpressionAccent(using: preset)
        drawMouth(using: preset)

        let nose = NSBezierPath()
        nose.move(to: NSPoint(x: 110, y: 124))
        nose.line(to: NSPoint(x: 98, y: 118))
        nose.line(to: NSPoint(x: 122, y: 118))
        nose.close()
        NSColor.systemPink.withAlphaComponent(0.85).setFill()
        nose.fill()
    }

    private func drawEyeLids(for eyeRect: NSRect, overlayHeight: CGFloat) {
        guard overlayHeight > 0 else {
            return
        }

        let lidRect = NSRect(
            x: eyeRect.minX,
            y: eyeRect.minY,
            width: eyeRect.width,
            height: min(eyeRect.height * 0.72, overlayHeight)
        )
        NSColor(calibratedRed: 0.88, green: 0.68, blue: 0.42, alpha: 0.92).setFill()
        NSBezierPath(roundedRect: lidRect, xRadius: lidRect.height / 2, yRadius: lidRect.height / 2).fill()
    }

    private func drawEyeSparkles(at pupilOrigin: CGPoint, pupilSize: NSSize, alpha: CGFloat) {
        guard alpha > 0 else {
            return
        }

        let sparkleRect = NSRect(
            x: pupilOrigin.x + pupilSize.width * 0.2,
            y: pupilOrigin.y + pupilSize.height * 0.18,
            width: 3,
            height: 3
        )
        NSColor.white.withAlphaComponent(alpha).setFill()
        NSBezierPath(ovalIn: sparkleRect).fill()
    }

    private func drawExpressionAccent(using preset: ExpressionPreset) {
        let strokeColor = NSColor.black.withAlphaComponent(0.22)
        strokeColor.setStroke()

        switch preset.accentStyle {
        case .typingBrow:
            let leftBrow = NSBezierPath()
            leftBrow.lineWidth = 2
            leftBrow.move(to: NSPoint(x: 74, y: 96))
            leftBrow.line(to: NSPoint(x: 100, y: 90))
            leftBrow.stroke()

            let rightBrow = NSBezierPath()
            rightBrow.lineWidth = 2
            rightBrow.move(to: NSPoint(x: 120, y: 90))
            rightBrow.line(to: NSPoint(x: 146, y: 96))
            rightBrow.stroke()
        case .generationFocus:
            let focusMark = NSBezierPath()
            focusMark.lineWidth = 2
            focusMark.move(to: NSPoint(x: 108, y: 82))
            focusMark.line(to: NSPoint(x: 108, y: 72))
            focusMark.move(to: NSPoint(x: 118, y: 78))
            focusMark.line(to: NSPoint(x: 124, y: 70))
            focusMark.stroke()
        case .none:
            return
        }
    }

    private func drawMouth(using preset: ExpressionPreset) {
        switch preset.mouth {
        case .focused:
            let mouth = NSBezierPath()
            mouth.lineWidth = 2
            mouth.move(to: NSPoint(x: 102, y: 134))
            mouth.line(to: NSPoint(x: 118, y: 134))
            NSColor.black.withAlphaComponent(0.35).setStroke()
            mouth.stroke()
        case .curiousClosed:
            let mouth = NSBezierPath()
            mouth.lineWidth = 2
            mouth.move(to: NSPoint(x: 104, y: 134))
            mouth.curve(to: NSPoint(x: 118, y: 134), controlPoint1: NSPoint(x: 108, y: 140), controlPoint2: NSPoint(x: 114, y: 140))
            NSColor.black.withAlphaComponent(0.32).setStroke()
            mouth.stroke()
        case .curiousOpen:
            let mouthRect = NSRect(x: 104, y: 131, width: 14, height: 12)
            NSColor(calibratedRed: 0.39, green: 0.18, blue: 0.17, alpha: 0.75).setFill()
            NSBezierPath(ovalIn: mouthRect).fill()
        case .softSmile:
            let mouth = NSBezierPath()
            mouth.lineWidth = 2
            mouth.move(to: NSPoint(x: 102, y: 132))
            mouth.curve(to: NSPoint(x: 120, y: 132), controlPoint1: NSPoint(x: 107, y: 139), controlPoint2: NSPoint(x: 115, y: 139))
            NSColor.black.withAlphaComponent(0.28).setStroke()
            mouth.stroke()
        case .resting:
            let mouth = NSBezierPath()
            mouth.lineWidth = 1.5
            mouth.move(to: NSPoint(x: 104, y: 135))
            mouth.line(to: NSPoint(x: 118, y: 135))
            NSColor.black.withAlphaComponent(0.20).setStroke()
            mouth.stroke()
        }
    }

    private func drawStatusBadge() {
        let badgeRect = NSRect(x: 34, y: 178, width: 152, height: 28)
        let badge = NSBezierPath(roundedRect: badgeRect, xRadius: 14, yRadius: 14)
        NSColor.black.withAlphaComponent(0.68).setFill()
        badge.fill()

        let text = permissionGranted ? "窗口与菜单栏已就绪" : "等待辅助功能权限"
        let style = NSMutableParagraphStyle()
        style.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
            .paragraphStyle: style
        ]

        let textRect = badgeRect.insetBy(dx: 8, dy: 6)
        text.draw(in: textRect, withAttributes: attributes)
    }

    private func drawTrackingBadge() {
        let badgeRect = NSRect(x: 20, y: 12, width: 180, height: 28)
        let badge = NSBezierPath(roundedRect: badgeRect, xRadius: 14, yRadius: 14)
        NSColor.black.withAlphaComponent(0.58).setFill()
        badge.fill()

        let style = NSMutableParagraphStyle()
        style.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white,
            .paragraphStyle: style
        ]

        trackingStatusText.draw(in: badgeRect.insetBy(dx: 8, dy: 7), withAttributes: attributes)
    }

    private func drawStateBadge() {
        let badgeRect = NSRect(x: 20, y: 44, width: 120, height: 28)
        let badge = NSBezierPath(roundedRect: badgeRect, xRadius: 14, yRadius: 14)
        NSColor.black.withAlphaComponent(0.58).setFill()
        badge.fill()

        let style = NSMutableParagraphStyle()
        style.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white,
            .paragraphStyle: style
        ]

        stateStatusText.draw(in: badgeRect.insetBy(dx: 8, dy: 7), withAttributes: attributes)
    }

    private func drawAttentionBadge() {
        let badgeRect = NSRect(x: 20, y: 76, width: 156, height: 28)
        let badge = NSBezierPath(roundedRect: badgeRect, xRadius: 14, yRadius: 14)

        let fillColor: NSColor
        switch attentionMode {
        case .typing:
            fillColor = NSColor(calibratedRed: 0.18, green: 0.22, blue: 0.16, alpha: 0.72)
        case .waitingForResponse:
            fillColor = NSColor(calibratedRed: 0.12, green: 0.22, blue: 0.26, alpha: 0.72)
        case .idle:
            fillColor = NSColor(calibratedWhite: 0.12, alpha: 0.56)
        }

        fillColor.setFill()
        badge.fill()

        let style = NSMutableParagraphStyle()
        style.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white,
            .paragraphStyle: style
        ]

        attentionMode.badgeText.draw(in: badgeRect.insetBy(dx: 8, dy: 7), withAttributes: attributes)
    }

    private func drawMappedTarget() {
        guard let mappedTargetPoint else {
            return
        }

        let ringRect = NSRect(
            x: mappedTargetPoint.x - 8,
            y: mappedTargetPoint.y - 8,
            width: 16,
            height: 16
        )
        let ring = NSBezierPath(ovalIn: ringRect)
        ring.lineWidth = 2
        NSColor.systemTeal.withAlphaComponent(0.95).setStroke()
        ring.stroke()

        let centerRect = NSRect(
            x: mappedTargetPoint.x - 2,
            y: mappedTargetPoint.y - 2,
            width: 4,
            height: 4
        )
        NSColor.systemTeal.withAlphaComponent(0.95).setFill()
        NSBezierPath(ovalIn: centerRect).fill()
    }

    private func pupilOrigin(in eyeRect: NSRect, pupilSize: NSSize, style: EyePreset) -> CGPoint {
        let neutralOrigin = CGPoint(
            x: eyeRect.midX - pupilSize.width / 2,
            y: eyeRect.midY - pupilSize.height / 2 + (attentionMode == .idle ? 1.5 : 0)
        )

        guard attentionMode != .idle, let mappedTargetPoint else {
            return neutralOrigin
        }

        let eyeCenter = CGPoint(x: eyeRect.midX, y: eyeRect.midY)
        let dx = mappedTargetPoint.x - eyeCenter.x
        let dy = mappedTargetPoint.y - eyeCenter.y
        let distance = hypot(dx, dy)

        guard distance > 0.001 else {
            return neutralOrigin
        }

        let normalizedX = dx / distance
        let normalizedY = dy / distance

        let offset = CGPoint(
            x: normalizedX * style.maxOffsetX,
            y: normalizedY * style.maxOffsetY
        )

        return CGPoint(
            x: neutralOrigin.x + offset.x,
            y: neutralOrigin.y + offset.y
        )
    }

    private func resolveExpressionPreset() -> ExpressionPreset {
        expressionPresetResolver.resolve(
            attentionMode: attentionMode,
            generationPhase: generationPhase,
            permissionGranted: permissionGranted
        )
    }

    private func bubblePresentation(for preset: ExpressionPreset) -> BubblePresentation? {
        expressionRuntimeState.bubblePresentation(for: preset)
    }

    private func bubbleAppearance(for style: BubbleVisualStyle) -> BubbleAppearance {
        switch style {
        case .neutral:
            return BubbleAppearance(
                fillColor: NSColor.white.withAlphaComponent(0.92),
                strokeColor: NSColor.black.withAlphaComponent(0.08),
                textColor: NSColor(calibratedRed: 0.18, green: 0.22, blue: 0.20, alpha: 0.92),
                borderWidth: 1
            )
        case .gentle:
            return BubbleAppearance(
                fillColor: NSColor(calibratedRed: 0.99, green: 0.95, blue: 0.86, alpha: 0.96),
                strokeColor: NSColor(calibratedRed: 0.84, green: 0.72, blue: 0.46, alpha: 0.58),
                textColor: NSColor(calibratedRed: 0.39, green: 0.31, blue: 0.18, alpha: 0.96),
                borderWidth: 1.1
            )
        case .curious:
            return BubbleAppearance(
                fillColor: NSColor(calibratedRed: 0.90, green: 0.97, blue: 0.98, alpha: 0.96),
                strokeColor: NSColor(calibratedRed: 0.38, green: 0.67, blue: 0.70, alpha: 0.55),
                textColor: NSColor(calibratedRed: 0.16, green: 0.33, blue: 0.36, alpha: 0.96),
                borderWidth: 1.2
            )
        case .pleased:
            return BubbleAppearance(
                fillColor: NSColor(calibratedRed: 0.99, green: 0.92, blue: 0.88, alpha: 0.96),
                strokeColor: NSColor(calibratedRed: 0.86, green: 0.57, blue: 0.47, alpha: 0.56),
                textColor: NSColor(calibratedRed: 0.42, green: 0.24, blue: 0.21, alpha: 0.95),
                borderWidth: 1.15
            )
        }
    }

    private func configureExpressionRuntimeState() {
        expressionRuntimeState.onPresentationInvalidated = { [weak self] in
            self?.needsDisplay = true
        }
    }
}
