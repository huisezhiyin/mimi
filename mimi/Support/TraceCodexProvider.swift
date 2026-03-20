import Foundation
import OSLog

final class TraceCodexProvider: GenerationSignalProvider {
    private struct SessionMetadata {
        let sessionId: String
        let workDir: String?
        let repoId: String?
        let branchName: String?
        let terminalType: String?
    }

    private struct SessionMetaLine: Decodable {
        let type: String
        let payload: SessionMetaPayload
    }

    private struct SessionMetaPayload: Decodable {
        let id: String?
        let cwd: String?
        let originator: String?
        let source: String?
    }

    private struct PreviousEntry {
        let fileSize: Int64
        let phase: GenerationPhase
        let metadata: SessionMetadata
    }

    let id = "codex-trace"
    private let logger = Logger(subsystem: "mimi", category: "codex-trace")

    private let sessionRootURLs: [URL]
    private let refreshInterval: TimeInterval
    private let activeWindow: TimeInterval
    private let streamingWindow: TimeInterval
    private let preparingWindow: TimeInterval
    private let settlingWindow: TimeInterval

    private var isStarted = false
    private var cachedSessions: [GenerationSessionSnapshot] = []
    private var lastRefreshAt: Date?
    private var previousEntries: [String: PreviousEntry] = [:]
    private var lastLoggedSummary: String?

    init(
        sessionRootURLs: [URL] = [
            URL(fileURLWithPath: NSString(string: "~/.codex_aicodewith/sessions").expandingTildeInPath),
            URL(fileURLWithPath: NSString(string: "~/.codex/sessions").expandingTildeInPath)
        ],
        refreshInterval: TimeInterval = 0.8,
        activeWindow: TimeInterval = 45,
        streamingWindow: TimeInterval = 2.2,
        preparingWindow: TimeInterval = 1.2,
        settlingWindow: TimeInterval = 20
    ) {
        self.sessionRootURLs = sessionRootURLs
        self.refreshInterval = refreshInterval
        self.activeWindow = activeWindow
        self.streamingWindow = streamingWindow
        self.preparingWindow = preparingWindow
        self.settlingWindow = settlingWindow
    }

    func start() {
        isStarted = true
        let roots = sessionRootURLs.map(\.path).joined(separator: ", ")
        logger.debug("TraceCodexProvider started. roots=\(roots, privacy: .public)")
    }

    func stop() {
        isStarted = false
        logger.debug("TraceCodexProvider stopped")
    }

    func currentSessions(now: Date) -> [GenerationSessionSnapshot] {
        guard isStarted else {
            return []
        }

        if let lastRefreshAt,
           now.timeIntervalSince(lastRefreshAt) < refreshInterval {
            return cachedSessions
        }

        let refreshedSessions = loadSessions(now: now)
        cachedSessions = refreshedSessions
        lastRefreshAt = now
        return refreshedSessions
    }

    private func loadSessions(now: Date) -> [GenerationSessionSnapshot] {
        var nextPreviousEntries: [String: PreviousEntry] = [:]
        var sessions: [GenerationSessionSnapshot] = []
        var candidateCount = 0
        var rootNotes: [String] = []

        for rootURL in sessionRootURLs {
            let rootResult = scanSessions(at: rootURL, now: now)
            candidateCount += rootResult.candidateCount
            sessions.append(contentsOf: rootResult.sessions)
            nextPreviousEntries.merge(rootResult.entries) { _, new in new }
            rootNotes.append(rootResult.note)
        }

        previousEntries = nextPreviousEntries
        let sortedSessions = sessions.sorted { lhs, rhs in
            lhs.updatedAt > rhs.updatedAt
        }
        logScanSummary(
            candidateCount: candidateCount,
            activeCount: sortedSessions.count,
            sessions: sortedSessions,
            note: rootNotes.joined(separator: "; ")
        )
        return sortedSessions
    }

    private func scanSessions(
        at rootURL: URL,
        now: Date
    ) -> (candidateCount: Int, sessions: [GenerationSessionSnapshot], entries: [String: PreviousEntry], note: String) {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return (0, [], [:], "\(rootURL.path)=missing")
        }

        var candidateCount = 0
        var sessions: [GenerationSessionSnapshot] = []
        var entries: [String: PreviousEntry] = [:]

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "jsonl" else {
                continue
            }

            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]),
                  resourceValues.isRegularFile == true,
                  let updatedAt = resourceValues.contentModificationDate,
                  let fileSize = resourceValues.fileSize else {
                continue
            }

            let age = now.timeIntervalSince(updatedAt)
            guard age <= activeWindow else {
                continue
            }

            candidateCount += 1

            let fileKey = fileURL.path
            let previousEntry = previousEntries[fileKey]
            let sizeDelta = max(0, Int64(fileSize) - (previousEntry?.fileSize ?? Int64(fileSize)))
            let metadata = previousEntry?.metadata ?? loadMetadata(from: fileURL)
            let phase = resolvePhase(
                age: age,
                sizeDelta: sizeDelta,
                isKnownSession: previousEntry != nil,
                previousPhase: previousEntry?.phase
            )

            entries[fileKey] = PreviousEntry(
                fileSize: Int64(fileSize),
                phase: phase,
                metadata: metadata
            )

            guard phase != .inactive else {
                continue
            }

            sessions.append(GenerationSessionSnapshot(
                providerId: id,
                sessionId: metadata.sessionId,
                phase: phase,
                updatedAt: updatedAt,
                workDir: metadata.workDir,
                repoId: metadata.repoId,
                branchName: metadata.branchName,
                terminalType: metadata.terminalType,
                outputAnchorRect: nil
            ))
        }

        return (
            candidateCount,
            sessions,
            entries,
            "\(rootURL.path)=\(candidateCount)/\(sessions.count)"
        )
    }

    private func logScanSummary(
        candidateCount: Int,
        activeCount: Int,
        sessions: [GenerationSessionSnapshot],
        note: String?
    ) {
        let sessionSummary = sessions.map { snapshot in
            let workDir = snapshot.workDir ?? "-"
            return "\(snapshot.phase.debugLabel):\(snapshot.sessionId):\(workDir)"
        }.joined(separator: " | ")

        let summary = "candidates=\(candidateCount) active=\(activeCount) sessions=[\(sessionSummary)] note=\(note ?? "-")"
        guard summary != lastLoggedSummary else {
            return
        }

        lastLoggedSummary = summary
        logger.debug("scan \(summary, privacy: .public)")
    }

    private func resolvePhase(
        age: TimeInterval,
        sizeDelta: Int64,
        isKnownSession: Bool,
        previousPhase: GenerationPhase?
    ) -> GenerationPhase {
        if !isKnownSession, age <= streamingWindow {
            return .streaming
        }

        if sizeDelta > 0, age <= streamingWindow {
            return .streaming
        }

        if sizeDelta == 0, previousPhase == .streaming, age <= 1.2 {
            return .streaming
        }

        if !isKnownSession, age <= preparingWindow {
            return .preparing
        }

        if !isKnownSession, age <= settlingWindow {
            return .settling
        }

        if previousPhase == .streaming || previousPhase == .preparing || previousPhase == .settling || sizeDelta > 0,
           age <= settlingWindow {
            return .settling
        }

        return .inactive
    }

    private func loadMetadata(from fileURL: URL) -> SessionMetadata {
        let fallbackSessionId = fileURL.deletingPathExtension().lastPathComponent
        let fallbackWorkDir: String? = nil
        let fallbackTerminalType = "codex"

        guard let handle = try? FileHandle(forReadingFrom: fileURL) else {
            return fallbackMetadata(
                sessionId: fallbackSessionId,
                workDir: fallbackWorkDir,
                terminalType: fallbackTerminalType
            )
        }

        defer {
            try? handle.close()
        }

        let chunk: Data?
        do {
            chunk = try handle.read(upToCount: 4096)
        } catch {
            chunk = nil
        }

        guard let data = chunk,
              let text = String(data: data, encoding: .utf8),
              let firstLine = text.split(separator: "\n", maxSplits: 1).first,
              let lineData = String(firstLine).data(using: .utf8),
              let metaLine = try? JSONDecoder().decode(SessionMetaLine.self, from: lineData),
              metaLine.type == "session_meta" else {
            return fallbackMetadata(
                sessionId: fallbackSessionId,
                workDir: fallbackWorkDir,
                terminalType: fallbackTerminalType
            )
        }

        let cwd = metaLine.payload.cwd
        let terminalType = [metaLine.payload.originator, metaLine.payload.source]
            .compactMap { value -> String? in
                guard let value, !value.isEmpty else {
                    return nil
                }
                return value
            }
            .joined(separator: " ")

        return SessionMetadata(
            sessionId: metaLine.payload.id ?? fallbackSessionId,
            workDir: cwd,
            repoId: cwd.map { URL(fileURLWithPath: $0).lastPathComponent },
            branchName: nil,
            terminalType: terminalType.isEmpty ? fallbackTerminalType : terminalType
        )
    }

    private func fallbackMetadata(
        sessionId: String,
        workDir: String?,
        terminalType: String
    ) -> SessionMetadata {
        SessionMetadata(
            sessionId: sessionId,
            workDir: workDir,
            repoId: workDir.map { URL(fileURLWithPath: $0).lastPathComponent },
            branchName: nil,
            terminalType: terminalType
        )
    }
}
