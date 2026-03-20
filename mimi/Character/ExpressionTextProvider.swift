import Foundation

struct BubbleTextRequest {
    let presetID: String
    let category: ExpressionCategory
    let style: BubbleVisualStyle
    let candidates: [String]
    let fallbackText: String
    let maxLength: Int
}

protocol ExpressionTextProvider: AnyObject {
    func generateText(for request: BubbleTextRequest, completion: @escaping (String?) -> Void)
}

extension ExpressionCategory {
    var llmLabel: String {
        switch self {
        case .typing:
            return "typing"
        case .generationPreparing:
            return "generation_preparing"
        case .generationStreaming:
            return "generation_streaming"
        case .generationSettling:
            return "generation_settling"
        case .idle:
            return "idle"
        }
    }
}

extension BubbleVisualStyle {
    var llmLabel: String {
        switch self {
        case .neutral:
            return "neutral"
        case .gentle:
            return "gentle"
        case .curious:
            return "curious"
        case .pleased:
            return "pleased"
        }
    }
}
