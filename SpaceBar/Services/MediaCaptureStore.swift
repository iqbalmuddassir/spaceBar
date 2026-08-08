import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class MediaCaptureStore: ObservableObject {
    @Published private(set) var items: [MediaCaptureItem] = []
    @Published var selectedIDs: Set<URL> = []
    @Published private(set) var isScanning = false
    @Published private(set) var isDeleting = false
    @Published private(set) var statusMessage: String?
    @Published var showBrowser = false
    @Published var confirmDelete = false

    var selectedItems: [MediaCaptureItem] {
        items.filter { selectedIDs.contains($0.id) }
    }

    var selectedBytes: UInt64 {
        selectedItems.reduce(0) { $0 + $1.byteSize }
    }

    var selectedBytesLabel: String {
        ByteFormatting.string(from: selectedBytes)
    }

    var totalBytes: UInt64 {
        items.reduce(0) { $0 + $1.byteSize }
    }

    var totalBytesLabel: String {
        ByteFormatting.string(from: totalBytes)
    }

    var screenshotCount: Int {
        items.filter { $0.kind == .screenshot }.count
    }

    var recordingCount: Int {
        items.filter { $0.kind == .recording }.count
    }

    var screenshotBytes: UInt64 {
        items.filter { $0.kind == .screenshot }.reduce(0) { $0 + $1.byteSize }
    }

    var recordingBytes: UInt64 {
        items.filter { $0.kind == .recording }.reduce(0) { $0 + $1.byteSize }
    }

    var summaryLabel: String {
        if items.isEmpty {
            return "None found"
        }
        var parts: [String] = []
        if screenshotCount > 0 {
            parts.append("\(screenshotCount) screenshots (\(ByteFormatting.string(from: screenshotBytes)))")
        }
        if recordingCount > 0 {
            parts.append("\(recordingCount) recordings (\(ByteFormatting.string(from: recordingBytes)))")
        }
        return parts.joined(separator: " · ")
    }

    var reclaimHint: String {
        guard totalBytes > 0 else { return "No media to reclaim" }
        return "Can free up to \(totalBytesLabel)"
    }

    private var statusClearTask: Task<Void, Never>?

    func scan() {
        isScanning = true
        statusMessage = "Scanning screenshots & recordings…"
        Task {
            let found = await Task.detached(priority: .utility) {
                MediaCaptureScanner.scan()
            }.value
            items = found
            // Drop selections that no longer exist
            selectedIDs = selectedIDs.intersection(Set(found.map(\.id)))
            isScanning = false
            if found.isEmpty {
                setStatus("No screenshots or recordings found")
            } else {
                setStatus("Found \(found.count) items · \(totalBytesLabel)")
            }
        }
    }

    func openBrowser() {
        showBrowser = true
        if items.isEmpty, !isScanning {
            scan()
        }
    }

    func closeBrowser() {
        showBrowser = false
        confirmDelete = false
    }

    func toggleSelection(_ id: URL) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    func selectAll() {
        selectedIDs = Set(items.map(\.id))
    }

    func selectNone() {
        selectedIDs.removeAll()
    }

    func selectOlderThan(days: Int) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        selectedIDs = Set(items.filter { $0.modified < cutoff }.map(\.id))
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
        let toDelete = selectedItems
        guard !toDelete.isEmpty else { return }

        isDeleting = true
        statusMessage = "Deleting \(toDelete.count) items…"

        Task {
            var deleted = 0
            var failed = 0
            var freed: UInt64 = 0

            for item in toDelete {
                let ok = await Task.detached(priority: .userInitiated) {
                    Self.forceRemove(item.url)
                }.value
                if ok {
                    deleted += 1
                    freed += item.byteSize
                    items.removeAll { $0.id == item.id }
                    selectedIDs.remove(item.id)
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

    private nonisolated static func forceRemove(_ url: URL) -> Bool {
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
