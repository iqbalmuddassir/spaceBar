import Foundation

enum CleanTargetCategory: String, CaseIterable {
    case general
    case xcode
    case mobile
    case packageManagers
    case devTools
    case aiTools
    case trash

    var title: String {
        switch self {
        case .general: "General"
        case .xcode: "Xcode"
        case .mobile: "Mobile & Build Tools"
        case .packageManagers: "Package Managers"
        case .devTools: "Developer Tools"
        case .aiTools: "AI Tools"
        case .trash: "Trash"
        }
    }
}

enum CleanStrategy: Equatable {
    case deletePaths([URL])
    case emptyTrash
    case simctlDeleteUnavailable
    case dockerBuilderPrune
}

struct CleanTarget: Identifiable, Equatable {
    let id: String
    let name: String
    let subtitle: String
    let safetyNote: String
    let strategy: CleanStrategy
    let requiresStrongConfirm: Bool
    let isPermanent: Bool
    var activity: CleanupActivity = .used
    var category: CleanTargetCategory = .general

    var confirmationMessage: String {
        if isPermanent {
            return "This permanently deletes everything in Trash and cannot be undone.\n\n\(safetyNote)"
        }
        if requiresStrongConfirm {
            return "\(name) will be deleted permanently so disk space frees immediately.\n\nWarning: \(safetyNote)"
        }
        return "\(name) will be deleted permanently so disk space frees immediately.\n\n\(safetyNote)"
    }
}

enum RowPhase: Equatable {
    case idle
    case scanning
    case ready
    case deleting
    case success
    case error(String)
}

struct TargetScanResult: Identifiable, Equatable {
    var id: String {
        target.id
    }

    let target: CleanTarget
    var byteSize: UInt64
    var staleDescription: String?
    var itemCount: Int?
    var phase: RowPhase
    var errorMessage: String?
    var recency: Recency?

    var sizeLabel: String {
        if target.isPermanent, byteSize == 0, (itemCount ?? 0) > 0 {
            return "size unknown"
        }
        return ByteFormatting.string(from: byteSize)
    }

    func temperature(staleAfter: TimeInterval, now: Date = Date()) -> RecencyTemperature? {
        recency?.temperature(staleAfter: staleAfter, now: now)
    }

    func isSafeByDefault(staleAfter: TimeInterval, now: Date = Date()) -> Bool {
        guard !target.isPermanent else { return false }
        guard !target.requiresStrongConfirm else { return false }
        guard let temperature = temperature(staleAfter: staleAfter, now: now) else { return false }
        return temperature.isSafeByDefault
    }

    var hasUnknownAge: Bool {
        !target.isPermanent && recency == nil
    }

    func recencyCaption(staleAfter: TimeInterval, now: Date = Date()) -> String? {
        if let caption = recency?.caption(staleAfter: staleAfter, now: now) {
            return caption
        }
        if let staleDescription {
            return staleDescription
        }
        if hasUnknownAge {
            return "Age unknown — review before cleaning"
        }
        return nil
    }

    var isVisible: Bool {
        if target.isPermanent {
            return byteSize > 0 || (itemCount ?? 0) > 0
        }
        return byteSize > 0
    }
}
