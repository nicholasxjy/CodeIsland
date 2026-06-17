import Foundation

struct YabaiSpaceInfo: Equatable, Identifiable {
    let index: Int
    let label: String?
    let isFocused: Bool

    var id: Int { index }
}

struct YabaiSpaceSnapshot: Equatable {
    let spaces: [YabaiSpaceInfo]

    var total: Int { spaces.count }
    var current: YabaiSpaceInfo? { spaces.first(where: \.isFocused) }
    var currentIndex: Int? { current?.index }
    var currentLabel: String? { current?.label }
}

struct YabaiSpaceTransition: Equatable {
    let fromIndex: Int?
    let toIndex: Int
    let toLabel: String?
}

enum YabaiSpaceQuery {
    private static let yabaiBinaryPaths = [
        "/opt/homebrew/bin/yabai",
        "/opt/homebrew/sbin/yabai",
        "/usr/local/bin/yabai",
        "/usr/local/sbin/yabai",
    ]

    static func yabaiBinaryPath(fileManager: FileManager = .default) -> String? {
        yabaiBinaryPaths.first { fileManager.isExecutableFile(atPath: $0) }
    }

    static func parseSpaces(_ data: Data) -> YabaiSpaceSnapshot? {
        guard let rawSpaces = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }

        let spaces = rawSpaces.compactMap { item -> YabaiSpaceInfo? in
            guard let index = item["index"] as? Int else { return nil }
            let rawLabel = (item["label"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let focused = Self.boolValue(item["has-focus"]) || Self.boolValue(item["focused"])
            return YabaiSpaceInfo(
                index: index,
                label: rawLabel?.isEmpty == false ? rawLabel : nil,
                isFocused: focused
            )
        }
        .sorted { $0.index < $1.index }

        guard !spaces.isEmpty else { return nil }
        return YabaiSpaceSnapshot(spaces: spaces)
    }

    private static func boolValue(_ value: Any?) -> Bool {
        if let bool = value as? Bool { return bool }
        if let int = value as? Int { return int == 1 }
        return false
    }
}

@MainActor
final class YabaiSpaceMonitor {
    private weak var appState: AppState?
    private var timer: Timer?
    private var isQuerying = false
    private let queryInterval: TimeInterval = 0.25

    init(appState: AppState) {
        self.appState = appState
    }

    func start() {
        guard timer == nil else { return }
        query()
        timer = Timer.scheduledTimer(withTimeInterval: queryInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.query()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func query() {
        guard !isQuerying else { return }
        isQuerying = true

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let data = YabaiSpaceQuery.yabaiBinaryPath().flatMap {
                ProcessRunner.run(
                    path: $0,
                    args: ["-m", "query", "--spaces"],
                    timeout: 1.5
                )
            }
            let snapshot = data.flatMap(YabaiSpaceQuery.parseSpaces)
            Task { @MainActor [weak self] in
                self?.isQuerying = false
                self?.appState?.updateYabaiSpaceSnapshot(snapshot)
            }
        }
    }
}
