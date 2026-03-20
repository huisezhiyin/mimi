import AppKit

enum CompanionState: String {
    case focus = "Focus"
    case wait = "Wait"
    case idle = "Idle"

    var badgeText: String {
        switch self {
        case .focus:
            return "状态：Focus"
        case .wait:
            return "状态：Wait"
        case .idle:
            return "状态：Idle"
        }
    }

    var debugDescription: String {
        switch self {
        case .focus:
            return "高频输入或近期活跃"
        case .wait:
            return "短暂停顿，进入等待态"
        case .idle:
            return "长时间无操作，进入休眠态"
        }
    }
}

struct CompanionStateConfig {
    let focusHoldDuration: TimeInterval
    let waitThreshold: TimeInterval
    let idleThreshold: TimeInterval
    let fastMouseMovementThreshold: CGFloat

    static let `default` = CompanionStateConfig(
        focusHoldDuration: 1.2,
        waitThreshold: 3,
        idleThreshold: 10,
        fastMouseMovementThreshold: 24
    )
}

struct CompanionStateEvaluation {
    let state: CompanionState
    let idleDuration: TimeInterval
    let reason: String

    var debugSummary: String {
        String(
            format: "当前状态：%@\n空闲时长：%.1fs\n判定原因：%@",
            state.rawValue,
            idleDuration,
            reason
        )
    }
}

final class CompanionStateMachine {
    private let config: CompanionStateConfig

    init(config: CompanionStateConfig = .default) {
        self.config = config
    }

    func evaluate(snapshot: ActivitySnapshot) -> CompanionStateEvaluation {
        let idleDuration = snapshot.idleDuration

        if idleDuration >= config.idleThreshold {
            return CompanionStateEvaluation(
                state: .idle,
                idleDuration: idleDuration,
                reason: "无操作超过 \(Int(config.idleThreshold)) 秒"
            )
        }

        if idleDuration >= config.waitThreshold {
            return CompanionStateEvaluation(
                state: .wait,
                idleDuration: idleDuration,
                reason: "无操作介于 \(Int(config.waitThreshold)) 到 \(Int(config.idleThreshold)) 秒之间"
            )
        }

        if let lastKeyboardActivityAt = snapshot.lastKeyboardActivityAt,
           snapshot.now.timeIntervalSince(lastKeyboardActivityAt) <= config.focusHoldDuration {
            return CompanionStateEvaluation(
                state: .focus,
                idleDuration: idleDuration,
                reason: "最近 \(String(format: "%.1f", config.focusHoldDuration)) 秒内检测到键盘输入"
            )
        }

        if let lastMouseActivityAt = snapshot.lastMouseActivityAt,
           snapshot.now.timeIntervalSince(lastMouseActivityAt) <= config.focusHoldDuration,
           snapshot.lastMouseMovementDistance >= config.fastMouseMovementThreshold {
            return CompanionStateEvaluation(
                state: .focus,
                idleDuration: idleDuration,
                reason: String(
                    format: "最近 %.1f 秒内检测到快速鼠标移动，位移 %.1f",
                    config.focusHoldDuration,
                    snapshot.lastMouseMovementDistance
                )
            )
        }

        return CompanionStateEvaluation(
            state: .focus,
            idleDuration: idleDuration,
            reason: "当前仍处于活跃窗口期内"
        )
    }
}
