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

    @Published var sortOrder: ReviewableSortOrder = .largest
    @Published var kindFilter: ReviewableFileKind?

    init(category: ReviewableFileCategory) {
        self.category = category
    }

    var title: String {
        category.title
    }

    var visibleFiles: [ReviewableFile] {
        files
            .filter { kindFilter == nil || $0.kind == kindFilter }
            .sorted(by: sortOrder.areInIncreasingOrder)
    }

    var availableKindFilters: [ReviewableFileKind] {
        category.kinds.count > 1 ? category.kinds : []
    }

    func count(of kind: ReviewableFileKind) -> Int {
        files.filter { $0.kind == kind }.count
    }

    var selectedFiles: [ReviewableFile] {
        files.filter { selectedIDs.contains($0.id) }
    }

    var hasSelectionOutsideFilter: Bool {
        selectedIDs.count > visibleFiles.filter { selectedIDs.contains($0.id) }.count
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

    private var scanGeneration = 0

    func scan() {
        scanTask?.cancel()
        scanGeneration += 1
        let generation = scanGeneration
        isScanning = true
        statusMessage = category.scanningStatus
        let category = category
        scanTask = Task { [weak self] in
            let found = await Task.detached(priority: .utility) {
                ReviewableFileScanner.scan(category: category)
            }.value
            guard let self, generation == scanGeneration else { return }
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
        guard !isScanning else { return }
        scan()
    }

    func closeBrowser() {
        showBrowser = false
        confirmDelete = false
    }

    func resetTransientUIState() {
        confirmDelete = false
        showBrowser = false
    }

    func clearForExclusion() {
        scanTask?.cancel()
        scanGeneration += 1
        isScanning = false
        files = []
        selectedIDs = []
        statusMessage = nil
        showBrowser = false
        confirmDelete = false
    }

    func loadFixture(files: [ReviewableFile], statusMessage: String? = nil) {
        scanTask?.cancel()
        scanGeneration += 1
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
        selectedIDs.formUnion(visibleFiles.map(\.id))
    }

    func selectNone() {
        selectedIDs.removeAll()
    }

    var areAllVisibleSelected: Bool {
        let visible = visibleFiles
        return !visible.isEmpty && visible.allSatisfy { selectedIDs.contains($0.id) }
    }

    func toggleSelectAll() {
        if areAllVisibleSelected {
            selectedIDs.subtract(visibleFiles.map(\.id))
        } else {
            selectAll()
        }
    }

    func selectOlderThan(days: Int) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        selectedIDs = Set(visibleFiles.filter { $0.modified < cutoff }.map(\.id))
    }

    func revealInFinder(_ file: ReviewableFile) {
        NSWorkspace.shared.activateFileViewerSelecting([file.url])
    }

    func requestDeleteSelected() {
        guard !selectedIDs.isEmpty else { return }
        confirmDelete = true
    }

    func cancelDelete() {
        confirmDelete = false
    }

    func deleteSelected(diskMonitor: DiskSpaceMonitor, settings: AppSettings) {
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
                let isDirectory = file.kind.isDirectory
                let didDelete = await Task.detached(priority: .userInitiated) {
                    Self.deleteFile(at: file.url, isDirectory: isDirectory)
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
            settings.addReclaimed(freed)
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

    private nonisolated static func deleteFile(at url: URL, isDirectory: Bool) -> Bool {
        do {
            if isDirectory {
                try DeletePathGuard.validateForBuildArtifactDelete(url)
            } else {
                try DeletePathGuard.validateForReviewableFileDelete(url)
            }
        } catch {
            return false
        }

        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/rm")
            process.arguments = [isDirectory ? "-rf" : "-f", url.path]
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
