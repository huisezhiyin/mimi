import AppKit

struct ExpressionPresetResolver {
    func resolve(
        attentionMode: AttentionMode,
        generationPhase: GenerationPhase,
        permissionGranted: Bool
    ) -> ExpressionPreset {
        let activePupilColor = permissionGranted
            ? NSColor.black.withAlphaComponent(0.85)
            : NSColor.systemOrange.withAlphaComponent(0.9)

        switch attentionMode {
        case .typing:
            return ExpressionPreset(
                id: "typing_focus",
                category: .typing,
                eye: EyePreset(
                    leftEyeRect: NSRect(x: 74, y: 98, width: 30, height: 19),
                    rightEyeRect: NSRect(x: 116, y: 98, width: 30, height: 19),
                    pupilSize: NSSize(width: 8, height: 15),
                    maxOffsetX: 7,
                    maxOffsetY: 4.4,
                    pupilColor: activePupilColor,
                    lidOverlayHeight: 3,
                    sparkleAlpha: 0.04
                ),
                mouth: .focused,
                ears: EarPreset(
                    earTipY: 16,
                    leftEarPeakX: 96,
                    rightEarPeakX: 172
                ),
                tail: TailPreset(
                    lineWidth: 18,
                    strokeColor: NSColor(calibratedRed: 0.86, green: 0.64, blue: 0.38, alpha: 0.95),
                    endPoint: NSPoint(x: 200, y: 60),
                    controlPoint1: NSPoint(x: 184, y: 128),
                    controlPoint2: NSPoint(x: 214, y: 102)
                ),
                accentStyle: .typingBrow,
                bubblePolicy: BubblePolicy(
                    enabled: false,
                    candidates: [],
                    minInterval: 0,
                    displayDuration: 0,
                    style: .neutral
                )
            )
        case .waitingForResponse:
            return waitingPreset(for: generationPhase, activePupilColor: activePupilColor)
        case .idle:
            return ExpressionPreset(
                id: "idle_rest",
                category: .idle,
                eye: EyePreset(
                    leftEyeRect: NSRect(x: 74, y: 102, width: 30, height: 12),
                    rightEyeRect: NSRect(x: 116, y: 102, width: 30, height: 12),
                    pupilSize: NSSize(width: 7, height: 7),
                    maxOffsetX: 1,
                    maxOffsetY: 1,
                    pupilColor: activePupilColor.withAlphaComponent(0.5),
                    lidOverlayHeight: 6,
                    sparkleAlpha: 0
                ),
                mouth: .resting,
                ears: EarPreset(
                    earTipY: 16,
                    leftEarPeakX: 96,
                    rightEarPeakX: 172
                ),
                tail: TailPreset(
                    lineWidth: 18,
                    strokeColor: NSColor(calibratedRed: 0.86, green: 0.64, blue: 0.38, alpha: 0.95),
                    endPoint: NSPoint(x: 200, y: 60),
                    controlPoint1: NSPoint(x: 184, y: 128),
                    controlPoint2: NSPoint(x: 214, y: 102)
                ),
                accentStyle: .none,
                bubblePolicy: BubblePolicy(
                    enabled: false,
                    candidates: [],
                    minInterval: 0,
                    displayDuration: 0,
                    style: .neutral
                )
            )
        }
    }

    private func waitingPreset(
        for generationPhase: GenerationPhase,
        activePupilColor: NSColor
    ) -> ExpressionPreset {
        switch generationPhase {
        case .preparing:
            return ExpressionPreset(
                id: "generation_prepare",
                category: .generationPreparing,
                eye: EyePreset(
                    leftEyeRect: NSRect(x: 74, y: 95, width: 30, height: 24),
                    rightEyeRect: NSRect(x: 116, y: 95, width: 30, height: 24),
                    pupilSize: NSSize(width: 9, height: 14),
                    maxOffsetX: 5.0,
                    maxOffsetY: 3.8,
                    pupilColor: activePupilColor.withAlphaComponent(0.86),
                    lidOverlayHeight: 3.5,
                    sparkleAlpha: 0.18
                ),
                mouth: .curiousClosed,
                ears: EarPreset(
                    earTipY: 11,
                    leftEarPeakX: 98,
                    rightEarPeakX: 170
                ),
                tail: TailPreset(
                    lineWidth: 19,
                    strokeColor: NSColor(calibratedRed: 0.89, green: 0.69, blue: 0.40, alpha: 0.97),
                    endPoint: NSPoint(x: 201, y: 52),
                    controlPoint1: NSPoint(x: 185, y: 122),
                    controlPoint2: NSPoint(x: 216, y: 92)
                ),
                accentStyle: .generationFocus,
                bubblePolicy: BubblePolicy(
                    enabled: true,
                    candidates: ["在看", "等下", "嗯"],
                    minInterval: 4.8,
                    displayDuration: 1.4,
                    style: .gentle
                )
            )
        case .streaming:
            return ExpressionPreset(
                id: "generation_watch",
                category: .generationStreaming,
                eye: EyePreset(
                    leftEyeRect: NSRect(x: 73, y: 95, width: 31, height: 26),
                    rightEyeRect: NSRect(x: 116, y: 95, width: 31, height: 26),
                    pupilSize: NSSize(width: 10, height: 15),
                    maxOffsetX: 4.2,
                    maxOffsetY: 3.4,
                    pupilColor: activePupilColor.withAlphaComponent(0.9),
                    lidOverlayHeight: 2.5,
                    sparkleAlpha: 0.40
                ),
                mouth: .curiousOpen,
                ears: EarPreset(
                    earTipY: 8,
                    leftEarPeakX: 102,
                    rightEarPeakX: 166
                ),
                tail: TailPreset(
                    lineWidth: 20,
                    strokeColor: NSColor(calibratedRed: 0.92, green: 0.72, blue: 0.41, alpha: 0.98),
                    endPoint: NSPoint(x: 202, y: 42),
                    controlPoint1: NSPoint(x: 186, y: 118),
                    controlPoint2: NSPoint(x: 218, y: 82)
                ),
                accentStyle: .generationFocus,
                bubblePolicy: BubblePolicy(
                    enabled: true,
                    candidates: ["唔...", "在写了", "盯住"],
                    minInterval: 4.0,
                    displayDuration: 1.6,
                    style: .curious
                )
            )
        case .settling:
            return ExpressionPreset(
                id: "generation_review",
                category: .generationSettling,
                eye: EyePreset(
                    leftEyeRect: NSRect(x: 73, y: 95, width: 31, height: 24),
                    rightEyeRect: NSRect(x: 116, y: 95, width: 31, height: 24),
                    pupilSize: NSSize(width: 9, height: 14),
                    maxOffsetX: 4.4,
                    maxOffsetY: 3.4,
                    pupilColor: activePupilColor.withAlphaComponent(0.88),
                    lidOverlayHeight: 3.0,
                    sparkleAlpha: 0.26
                ),
                mouth: .softSmile,
                ears: EarPreset(
                    earTipY: 10,
                    leftEarPeakX: 100,
                    rightEarPeakX: 168
                ),
                tail: TailPreset(
                    lineWidth: 19,
                    strokeColor: NSColor(calibratedRed: 0.90, green: 0.70, blue: 0.40, alpha: 0.97),
                    endPoint: NSPoint(x: 201, y: 50),
                    controlPoint1: NSPoint(x: 185, y: 120),
                    controlPoint2: NSPoint(x: 217, y: 88)
                ),
                accentStyle: .generationFocus,
                bubblePolicy: BubblePolicy(
                    enabled: true,
                    candidates: ["嗯？", "好了？", "看看"],
                    minInterval: 5.2,
                    displayDuration: 1.5,
                    style: .pleased
                )
            )
        case .inactive:
            return ExpressionPreset(
                id: "typing_soft",
                category: .typing,
                eye: EyePreset(
                    leftEyeRect: NSRect(x: 74, y: 96, width: 30, height: 24),
                    rightEyeRect: NSRect(x: 116, y: 96, width: 30, height: 24),
                    pupilSize: NSSize(width: 9, height: 14),
                    maxOffsetX: 5.5,
                    maxOffsetY: 4,
                    pupilColor: activePupilColor.withAlphaComponent(0.82),
                    lidOverlayHeight: 4,
                    sparkleAlpha: 0.20
                ),
                mouth: .curiousClosed,
                ears: EarPreset(
                    earTipY: 16,
                    leftEarPeakX: 96,
                    rightEarPeakX: 172
                ),
                tail: TailPreset(
                    lineWidth: 18,
                    strokeColor: NSColor(calibratedRed: 0.86, green: 0.64, blue: 0.38, alpha: 0.95),
                    endPoint: NSPoint(x: 200, y: 60),
                    controlPoint1: NSPoint(x: 184, y: 128),
                    controlPoint2: NSPoint(x: 214, y: 102)
                ),
                accentStyle: .none,
                bubblePolicy: BubblePolicy(
                    enabled: false,
                    candidates: [],
                    minInterval: 0,
                    displayDuration: 0,
                    style: .neutral
                )
            )
        }
    }
}
