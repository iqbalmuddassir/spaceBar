import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class ReviewableFilesStore: ObservableObject {
    let category: ReviewableFileCategory

    @Published private(set) var files: [ReviewableFile] = []
    @Published var selectedIDs: Set<URL> = []
    @Published private(set) var isScanning = false
    @Published private(set) var isDeleting = false
    @Published private(set) var statusMessage: String?
    @Published var showBrowser = false
    @Published var confirmDelete = false

    init(category: ReviewableFileCategory) {
        self.category = category
    }

    var title: String {
        category.title
    }

    var selectedFiles: [ReviewableFile] {
        files.filter { selectedIDs.contains($0.id) }
    }

    var selectedBytes: UInt64 {
        selectedFiles.reduce(0) { $0 + $1.byteSize }
    }

    var selectedBytesLabel: String {
        ByteFormatting.string(from: selectedBytes)
    }

    var totalBytes: UInt64 {
        files.reduce(0) { $0 + $1.byteSize }
    }

    var totalBytesLabel: String {
        ByteFormatting.string(from: totalBytes)
    }

    var summaryLabel: String {
        if files.isEmpty {
            return "None found"
        }
        let parts: [String] = category.kinds.compactMap { kind in
            let matching = files.filter { $0.kind == kind }
            guard !matching.isEmpty else { return nil }
            let bytes = matching.reduce(0) { $0 + $1.byteSize }
            return "\(matching.count) \(kind.pluralLabel) (\(ByteFormatting.string(from: bytes)))"
        }
        return parts.joined(separator: " · ")
    }

    var reclaimHint: String {
        guard totalBytes > 0 else { return category.emptyReclaimHint }
        return "Can free up to \(totalBytesLabel)"
    }

    private var statusClearTask: Task<Void, Never>?
    private var scanTask: Task<Void, Never>?

    func scan() {
        scanTask?.cancel()
        isScanning = true
        statusMessage = category.scanningStatus
        let category = category
        scanTask = Task {
            let found = await Task.detached(priority: .utility) {
                ReviewableFileScanner.scan(category: category)
            }.value
            guard !Task.isCancelled else {
                isScanning = false
                return
            }
            files = found
            selectedIDs = selectedIDs.intersection(Set(found.map(\.id)))
            isScanning = false
            if found.isEmpty {
                setStatus(category.emptyStatus)
            } else {
                setStatus("Found \(found.count) items · \(totalBytesLabel)")
            }
        }
    }

    func openBrowser() {
        showBrowser = true
        if files.isEmpty, !isScanning {
            scan()
        }
    }

    func closeBrowser() {
        showBrowser = false
        confirmDelete = false
    }

    func resetTransientUIState() {
        confirmDelete = false
        showBrowser = false
    }

    func loadFixture(files: [ReviewableFile], statusMessage: String? = nil) {
        scanTask?.cancel()
        isScanning = false
        isDeleting = false
        confirmDelete = false
        showBrowser = false
        self.files = files
        selectedIDs = []
        self.statusMessage = statusMessage
    }

    func toggleSelection(_ id: URL) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    func selectAll() {
        selectedIDs = Set(files.map(\.id))
    }

    func selectNone() {
        selectedIDs.removeAll()
    }

    func selectOlderThan(days: Int) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        selectedIDs = Set(files.filter { $0.modified < cutoff }.map(\.id))
    }

    func requestDeleteSelected() {
        guard !selectedIDs.isEmpty else { return }
        confirmDelete = true
    }

    func cancelDelete() {
        confirmDelete = false
    }

    func deleteSelected(diskMonitor: DiskSpaceMonitor) {
        confirmDelete = false
        let filesToDelete = selectedFiles
        guard !filesToDelete.isEmpty else { return }

        isDeleting = true
        statusMessage = "Deleting \(filesToDelete.count) items…"

        Task {
            var deleted = 0
            var failed = 0
            var freed: UInt64 = 0

            for file in filesToDelete {
                let didDelete = await Task.detached(priority: .userInitiated) {
                    Self.deleteFile(at: file.url)
                }.value
                if didDelete {
                    deleted += 1
                    freed += file.byteSize
                    files.removeAll { $0.id == file.id }
                    selectedIDs.remove(file.id)
                } else {
                    failed += 1
                }
            }

            isDeleting = false
            let freedLabel = ByteFormatting.string(from: freed)
            if failed == 0 {
                setStatus("Deleted \(deleted) · freed \(freedLabel)")
            } else {
                setStatus("Deleted \(deleted), failed \(failed) · freed \(freedLabel)")
            }
            await diskMonitor.refreshAfterCleaning()
        }
    }

    private func setStatus(_ message: String) {
        statusMessage = message
        statusClearTask?.cancel()
        statusClearTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if !Task.isCancelled {
                statusMessage = nil
            }
        }
    }

    private nonisolated static func deleteFile(at url: URL) -> Bool {
        do {
            try DeletePathGuard.validateForReviewableFileDelete(url)
        } catch {
            return false
        }

        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/rm")
            process.arguments = ["-f", url.path]
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            do {
                try process.run()
                process.waitUntilExit()
                return process.terminationStatus == 0 && !FileManager.default.fileExists(atPath: url.path)
            } catch {
                return false
            }
        }
    }
}
