import AppKit
import OSLog

enum GenerationPhase: Int {
    case inactive = 0
    case settling = 1
    case preparing = 2
    case streaming = 3

    var debugLabel: String {
        switch self {
        case .inactive:
            return "inactive"
        case .settling:
            return "settling"
        case .preparing:
            return "preparing"
        case .streaming:
            return "streaming"
        }
    }
}

struct GenerationSessionSnapshot {
    let providerId: String
    let sessionId: String
    let phase: GenerationPhase
    let updatedAt: Date
    let workDir: String?
    let repoId: String?
    let branchName: String?
    let terminalType: String?
    let outputAnchorRect: CGRect?

    var debugSummary: String {
        let phaseLine = "阶段：\(phase.debugLabel)"
        let sessionLine = "会话：\(sessionId)"
        let workDirLine = "目录：\(workDir ?? "未知")"
        let terminalLine = "终端：\(terminalType ?? "未知")"
        return [phaseLine, sessionLine, workDirLine, terminalLine].joined(separator: "\n")
    }
}

struct GenerationSignalSnapshot {
    let phase: GenerationPhase
    let source: String
    let confidence: Double
    let updatedAt: Date
    let outputAnchorRect: CGRect?
    let sessionId: String
    let workDir: String?
    let terminalType: String?
    let activeSessionCount: Int

    var debugSummary: String {
        let phaseLine = "生成阶段：\(phase.debugLabel)"
        let sourceLine = "来源：\(source)"
        let sessionLine = "主会话：\(sessionId)"
        let workDirLine = "目录：\(workDir ?? "未知")"
        let terminalLine = "终端：\(terminalType ?? "未知")"
        let sessionCountLine = "活跃会话数：\(activeSessionCount)"
        let confidenceLine = String(format: "置信度：%.2f", confidence)
        return [
            phaseLine,
            sourceLine,
            sessionLine,
            workDirLine,
            terminalLine,
            sessionCountLine,
            confidenceLine
        ].joined(separator: "\n")
    }
}

protocol GenerationSignalProvider {
    var id: String { get }
    func start()
    func stop()
    func currentSessions(now: Date) -> [GenerationSessionSnapshot]
}

final class GenerationSessionCoordinator {
    private let providers: [GenerationSignalProvider]
    private let logger = Logger(subsystem: "mimi", category: "generation-coordinator")
    private var lastLoggedSelectionSummary: String?

    init(providers: [GenerationSignalProvider]) {
        self.providers = providers
    }

    func start() {
        providers.forEach { $0.start() }
    }

    func stop() {
        providers.forEach { $0.stop() }
    }

    func currentSnapshot(now: Date, frontmostAppName: String?) -> GenerationSignalSnapshot? {
        let sessions = providers
            .flatMap { $0.currentSessions(now: now) }
            .filter { $0.phase != .inactive }

        guard let activeSession = selectActiveSession(from: sessions, frontmostAppName: frontmostAppName) else {
            logSelection(frontmostAppName: frontmostAppName, sessions: sessions, activeSession: nil)
            return nil
        }

        let confidence = resolvedConfidence(for: activeSession, frontmostAppName: frontmostAppName)
        logSelection(frontmostAppName: frontmostAppName, sessions: sessions, activeSession: activeSession)

        return GenerationSignalSnapshot(
            phase: activeSession.phase,
            source: activeSession.providerId,
            confidence: confidence,
            updatedAt: activeSession.updatedAt,
            outputAnchorRect: activeSession.outputAnchorRect,
            sessionId: activeSession.sessionId,
            workDir: activeSession.workDir,
            terminalType: activeSession.terminalType,
            activeSessionCount: sessions.count
        )
    }

    private func logSelection(
        frontmostAppName: String?,
        sessions: [GenerationSessionSnapshot],
        activeSession: GenerationSessionSnapshot?
    ) {
        let summary = [
            "frontmost=\(frontmostAppName ?? "-")",
            "count=\(sessions.count)",
            "picked=\(activeSession?.sessionId ?? "-")",
            "phase=\(activeSession?.phase.debugLabel ?? "-")"
        ].joined(separator: " ")

        guard summary != lastLoggedSelectionSummary else {
            return
        }

        lastLoggedSelectionSummary = summary
        logger.debug("selection \(summary, privacy: .public)")
    }

    private func selectActiveSession(
        from sessions: [GenerationSessionSnapshot],
        frontmostAppName: String?
    ) -> GenerationSessionSnapshot? {
        sessions.max { lhs, rhs in
            sortKey(for: lhs, frontmostAppName: frontmostAppName) < sortKey(for: rhs, frontmostAppName: frontmostAppName)
        }
    }

    private func sortKey(
        for session: GenerationSessionSnapshot,
        frontmostAppName: String?
    ) -> (Int, Int, Date) {
        (
            frontmostBoost(for: session, frontmostAppName: frontmostAppName),
            session.phase.rawValue,
            session.updatedAt
        )
    }

    private func frontmostBoost(
        for session: GenerationSessionSnapshot,
        frontmostAppName: String?
    ) -> Int {
        guard let frontmostAppName else {
            return 0
        }

        let appName = frontmostAppName.lowercased()
        let terminalType = session.terminalType?.lowercased() ?? ""

        if appName.contains("codex"), terminalType.contains("codex") {
            return 2
        }

        let terminalAppKeywords = ["terminal", "iterm", "warp", "ghostty", "kitty", "wezterm", "alacritty"]
        if terminalAppKeywords.contains(where: { appName.contains($0) }),
           terminalType.contains("cli") || terminalType.contains("terminal") || terminalType.contains("codex_cli_rs") {
            return 1
        }

        return 0
    }

    private func resolvedConfidence(
        for session: GenerationSessionSnapshot,
        frontmostAppName: String?
    ) -> Double {
        let base: Double
        switch session.phase {
        case .streaming:
            base = 0.92
        case .preparing:
            base = 0.80
        case .settling:
            base = 0.70
        case .inactive:
            base = 0.0
        }

        let boosted = base + Double(frontmostBoost(for: session, frontmostAppName: frontmostAppName)) * 0.04
        return min(0.99, boosted)
    }
}
