import AppKit

enum AttentionMode: Equatable {
    case typing
    case waitingForResponse
    case idle

    var badgeText: String {
        switch self {
        case .typing:
            return "注意力：监督输入"
        case .waitingForResponse:
            return "注意力：好奇等待"
        case .idle:
            return "注意力：休息中"
        }
    }
}

struct MousePointerSnapshot {
    let point: CGPoint
    let isFromGlobalMonitor: Bool

    var debugSummary: String {
        let source = isFromGlobalMonitor ? "全局鼠标监听" : "系统当前鼠标位置"
        return String(
            format: "来源：%@\n全局坐标：x=%.1f, y=%.1f",
            source,
            point.x,
            point.y
        )
    }
}

enum TrackingTarget {
    case cursor(TextCursorSnapshot)
    case cursorHold(TextCursorSnapshot, age: TimeInterval)
    case generation(GenerationSignalSnapshot, anchorRect: CGRect)
    case screenChange(ScreenChangeObservation)
    case mouse(MousePointerSnapshot, fallbackReason: TextCursorProbeError?)
    case unavailable(reason: String)
}

extension TrackingTarget {
    var globalPoint: CGPoint? {
        switch self {
        case .cursor(let snapshot):
            return CGPoint(x: snapshot.rect.midX, y: snapshot.rect.midY)
        case .cursorHold(let snapshot, _):
            return CGPoint(x: snapshot.rect.midX, y: snapshot.rect.midY)
        case .generation(_, let anchorRect):
            return CGPoint(x: anchorRect.midX, y: anchorRect.midY)
        case .screenChange(let observation):
            return observation.dominantPoint ?? CGPoint(x: observation.watchRect.midX, y: observation.watchRect.midY)
        case .mouse(let snapshot, _):
            return snapshot.point
        case .unavailable:
            return nil
        }
    }

    var debugSummary: String {
        switch self {
        case .cursor(let snapshot):
            return "目标来源：文本光标\n\(snapshot.debugSummary)"
        case .cursorHold(let snapshot, let age):
            return String(
                format: "目标来源：文本光标保活\n保活时长：%.2fs\n%@",
                age,
                snapshot.debugSummary
            )
        case .generation(let snapshot, let anchorRect):
            return String(
                format: "目标来源：Codex 生成信号\n%@\n输出锚点：x=%.1f, y=%.1f, width=%.1f, height=%.1f",
                snapshot.debugSummary,
                anchorRect.origin.x,
                anchorRect.origin.y,
                anchorRect.size.width,
                anchorRect.size.height
            )
        case .screenChange(let observation):
            return "目标来源：局部屏幕变化\n\(observation.debugSummary)"
        case .mouse(let snapshot, let fallbackReason):
            if let fallbackReason {
                return "目标来源：鼠标 fallback\nfallback 原因：\(fallbackReason.messageText)\n\(snapshot.debugSummary)"
            }

            return "目标来源：鼠标\n\(snapshot.debugSummary)"
        case .unavailable(let reason):
            return "目标不可用\n\(reason)"
        }
    }
}
