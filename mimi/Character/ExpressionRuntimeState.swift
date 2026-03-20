import Foundation

final class ExpressionRuntimeState {
    var onPresentationInvalidated: (() -> Void)?

    private let textProvider: ExpressionTextProvider?
    private var activeBubblePresentation: BubblePresentation?
    private var activeBubblePresetID: String?
    private var activeBubbleUntil: Date?
    private var lastBubbleShownAtByPreset: [String: Date] = [:]
    private var lastBubbleTextByPreset: [String: String] = [:]
    private var pendingRequestTokenByPreset: [String: UUID] = [:]

    init(textProvider: ExpressionTextProvider? = nil) {
        self.textProvider = textProvider
    }

    func bubblePresentation(for preset: ExpressionPreset, now: Date = Date()) -> BubblePresentation? {
        guard preset.bubblePolicy.enabled, preset.bubblePolicy.candidates.isEmpty == false else {
            resetActiveBubble()
            return nil
        }

        if activeBubblePresetID == preset.id,
           let activeBubblePresentation,
           let activeBubbleUntil,
           now < activeBubbleUntil {
            return activeBubblePresentation
        }

        let lastShownAt = lastBubbleShownAtByPreset[preset.id] ?? .distantPast
        guard now.timeIntervalSince(lastShownAt) >= preset.bubblePolicy.minInterval else {
            if activeBubblePresetID == preset.id {
                resetActiveBubble()
            }
            return nil
        }

        let nextBubbleText = nextBubbleText(for: preset)
        let bubblePresentation = BubblePresentation(
            text: nextBubbleText,
            style: preset.bubblePolicy.style
        )
        activeBubblePresetID = preset.id
        activeBubblePresentation = bubblePresentation
        activeBubbleUntil = now.addingTimeInterval(preset.bubblePolicy.displayDuration)
        lastBubbleShownAtByPreset[preset.id] = now
        lastBubbleTextByPreset[preset.id] = nextBubbleText
        requestGeneratedBubbleTextIfNeeded(for: preset, fallbackText: nextBubbleText)
        return bubblePresentation
    }

    private func nextBubbleText(for preset: ExpressionPreset) -> String {
        let candidates = preset.bubblePolicy.candidates
        guard candidates.count > 1 else {
            return candidates[0]
        }

        let lastBubbleText = lastBubbleTextByPreset[preset.id]
        let filteredCandidates = candidates.filter { $0 != lastBubbleText }
        return (filteredCandidates.isEmpty ? candidates : filteredCandidates).randomElement() ?? candidates[0]
    }

    private func resetActiveBubble() {
        activeBubblePresetID = nil
        activeBubblePresentation = nil
        activeBubbleUntil = nil
    }

    private func requestGeneratedBubbleTextIfNeeded(for preset: ExpressionPreset, fallbackText: String) {
        guard let textProvider else {
            return
        }

        let requestToken = UUID()
        pendingRequestTokenByPreset[preset.id] = requestToken

        let request = BubbleTextRequest(
            presetID: preset.id,
            category: preset.category,
            style: preset.bubblePolicy.style,
            candidates: preset.bubblePolicy.candidates,
            fallbackText: fallbackText,
            maxLength: 8
        )

        textProvider.generateText(for: request) { [weak self] generatedText in
            self?.applyGeneratedBubbleText(
                generatedText,
                for: preset,
                requestToken: requestToken
            )
        }
    }

    private func applyGeneratedBubbleText(
        _ generatedText: String?,
        for preset: ExpressionPreset,
        requestToken: UUID,
        now: Date = Date()
    ) {
        guard pendingRequestTokenByPreset[preset.id] == requestToken else {
            return
        }
        pendingRequestTokenByPreset[preset.id] = nil

        guard
            activeBubblePresetID == preset.id,
            let activeBubbleUntil,
            now < activeBubbleUntil,
            let sanitizedText = sanitizeGeneratedText(generatedText, maxLength: 8),
            sanitizedText != activeBubblePresentation?.text
        else {
            return
        }

        activeBubblePresentation = BubblePresentation(
            text: sanitizedText,
            style: preset.bubblePolicy.style
        )
        lastBubbleTextByPreset[preset.id] = sanitizedText
        onPresentationInvalidated?()
    }

    private func sanitizeGeneratedText(_ text: String?, maxLength: Int) -> String? {
        guard let text else {
            return nil
        }

        let normalized = text
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "“", with: "")
            .replacingOccurrences(of: "”", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalized.isEmpty == false else {
            return nil
        }

        return String(normalized.prefix(maxLength))
    }
}
