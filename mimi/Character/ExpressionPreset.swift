import AppKit

enum ExpressionCategory {
    case typing
    case generationPreparing
    case generationStreaming
    case generationSettling
    case idle
}

enum MouthPreset {
    case focused
    case curiousClosed
    case curiousOpen
    case softSmile
    case resting
}

enum ExpressionAccentStyle {
    case typingBrow
    case generationFocus
    case none
}

struct EyePreset {
    let leftEyeRect: NSRect
    let rightEyeRect: NSRect
    let pupilSize: NSSize
    let maxOffsetX: CGFloat
    let maxOffsetY: CGFloat
    let pupilColor: NSColor
    let lidOverlayHeight: CGFloat
    let sparkleAlpha: CGFloat
}

struct EarPreset {
    let earTipY: CGFloat
    let leftEarPeakX: CGFloat
    let rightEarPeakX: CGFloat
}

struct TailPreset {
    let lineWidth: CGFloat
    let strokeColor: NSColor
    let endPoint: NSPoint
    let controlPoint1: NSPoint
    let controlPoint2: NSPoint
}

struct BubblePolicy {
    let enabled: Bool
    let candidates: [String]
    let minInterval: TimeInterval
    let displayDuration: TimeInterval
    let style: BubbleVisualStyle
}

enum BubbleVisualStyle {
    case neutral
    case gentle
    case curious
    case pleased
}

struct BubblePresentation {
    let text: String
    let style: BubbleVisualStyle
}

struct ExpressionPreset {
    let id: String
    let category: ExpressionCategory
    let eye: EyePreset
    let mouth: MouthPreset
    let ears: EarPreset
    let tail: TailPreset
    let accentStyle: ExpressionAccentStyle
    let bubblePolicy: BubblePolicy
}
