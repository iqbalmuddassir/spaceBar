import Foundation

extension CleanupStore {
    /// Rows the user has ticked, or — before they touch anything — the ones recency says are cold.
    func isSelected(_ result: TargetScanResult, staleAfter: TimeInterval, now: Date = Date()) -> Bool {
        if let explicit = explicitSelection[result.id] {
            return explicit
        }
        return result.isSafeByDefault(staleAfter: staleAfter, now: now)
    }

    func toggleSelection(_ result: TargetScanResult, staleAfter: TimeInterval, now: Date = Date()) {
        let current = isSelected(result, staleAfter: staleAfter, now: now)
        explicitSelection[result.id] = !current
    }

    func setAllSelected(_ selected: Bool) {
        for result in results where !result.target.isPermanent || selected == false {
            explicitSelection[result.id] = selected
        }
        if selected {
            // Trash is the one irreversible target, so "select all" still leaves it opted out.
            for result in results where result.target.isPermanent {
                explicitSelection[result.id] = false
            }
        }
    }

    func clearSelectionOverrides() {
        explicitSelection.removeAll()
    }

    func selectedResults(staleAfter: TimeInterval, now: Date = Date()) -> [TargetScanResult] {
        results.filter { isSelected($0, staleAfter: staleAfter, now: now) && $0.byteSize > 0 }
    }

    func selectedBytes(staleAfter: TimeInterval, now: Date = Date()) -> UInt64 {
        selectedResults(staleAfter: staleAfter, now: now).reduce(0) { $0 + $1.byteSize }
    }

    /// Rows left unticked only because they were touched recently — the footer explains these,
    /// so a user never wonders why the total is lower than the reclaimable figure.
    func heldBackCount(staleAfter: TimeInterval, now: Date = Date()) -> Int {
        results.filter { result in
            guard explicitSelection[result.id] == nil else { return false }
            guard !result.target.isPermanent else { return false }
            guard let temperature = result.temperature(staleAfter: staleAfter, now: now) else { return false }
            return !temperature.isSafeByDefault
        }.count
    }

    func selectionSummary(staleAfter: TimeInterval, now: Date = Date()) -> String? {
        let held = heldBackCount(staleAfter: staleAfter, now: now)
        guard held > 0 else { return nil }
        let noun = held == 1 ? "item" : "items"
        let pronoun = held == 1 ? "it was" : "they were"
        return "\(held) \(noun) left unticked because \(pronoun) touched recently."
    }
}
