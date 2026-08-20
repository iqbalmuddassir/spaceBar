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
    /// Names what actually happened to this target, so the row reads "Built 20 minutes ago"
    /// rather than the filesystem's "last modified".
    var activity: CleanupActivity = .used
    var category: CleanTargetCategory = .general

    var confirmationTitle: String {
        isPermanent ? "Empty Trash permanently?" : "Delete permanently?"
    }

    var confirmationMessage: String {
        if isPermanent {
            return "This permanently deletes everything in Trash and cannot be undone.\n\n\(safetyNote)"
        }
        if requiresStrongConfirm {
            return "\(name) will be deleted permanently so disk space frees immediately.\n\nWarning: \(safetyNote)"
        }
        return "\(name) will be deleted permanently so disk space frees immediately.\n\n\(safetyNote)"
    }

    var confirmButtonTitle: String {
        isPermanent ? "Empty Trash" : "Delete"
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
        ByteFormatting.string(from: byteSize)
    }

    func temperature(staleAfter: TimeInterval, now: Date = Date()) -> RecencyTemperature? {
        recency?.temperature(staleAfter: staleAfter, now: now)
    }

    /// Cold targets arrive pre-selected; anything touched more recently is left for the user
    /// to opt into, so the one-press cleanup never removes something in active use.
    func isSafeByDefault(staleAfter: TimeInterval, now: Date = Date()) -> Bool {
        guard !target.isPermanent else { return false }
        guard let temperature = temperature(staleAfter: staleAfter, now: now) else { return true }
        return temperature.isSafeByDefault
    }

    func recencyCaption(staleAfter: TimeInterval, now: Date = Date()) -> String? {
        recency?.caption(staleAfter: staleAfter, now: now) ?? staleDescription
    }

    var isVisible: Bool {
        if target.isPermanent {
            return byteSize > 0 || (itemCount ?? 0) > 0
        }
        return byteSize > 0
    }
}
