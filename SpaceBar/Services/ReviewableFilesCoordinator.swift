import Combine
import Foundation

@MainActor
final class ReviewableFilesCoordinator: ObservableObject {
    let stores: [ReviewableFilesStore]

    @Published var excludedIDs: Set<String> = [] {
        didSet {
            for store in stores where excludedIDs.contains(store.category.settingsID) {
                store.clearForExclusion()
            }
        }
    }

    private var cancellables = Set<AnyCancellable>()

    init(categories: [ReviewableFileCategory] = ReviewableFileCategory.allCases) {
        stores = categories.map { ReviewableFilesStore(category: $0) }
        for store in stores {
            store.objectWillChange
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }
    }

    var activeStores: [ReviewableFilesStore] {
        stores.filter { !excludedIDs.contains($0.category.settingsID) }
    }

    var activeBrowserStore: ReviewableFilesStore? {
        stores.first { $0.showBrowser }
    }

    var totalReclaimableBytes: UInt64 {
        activeStores.reduce(0) { $0 + $1.totalBytes }
    }

    var totalReclaimableLabel: String {
        ByteFormatting.string(from: totalReclaimableBytes)
    }

    var isDeletingAny: Bool {
        stores.contains(where: \.isDeleting)
    }

    var isConfirmingAnyDelete: Bool {
        stores.contains(where: \.confirmDelete)
    }

    func scanAll() {
        activeStores.forEach { $0.scan() }
    }

    func closeAllBrowsers() {
        stores.forEach { $0.closeBrowser() }
    }

    func resetTransientUIState() {
        stores.forEach { $0.resetTransientUIState() }
    }
}
