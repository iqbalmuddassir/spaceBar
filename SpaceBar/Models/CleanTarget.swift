import Foundation

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

    var sizeLabel: String {
        ByteFormatting.string(from: byteSize)
    }

    var isVisible: Bool {
        if target.isPermanent {
            return byteSize > 0 || (itemCount ?? 0) > 0
        }
        return byteSize > 0
    }
}
