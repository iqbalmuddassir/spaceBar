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
        results.filter { result in
            guard isSelected(result, staleAfter: staleAfter, now: now) else { return false }
            if result.target.isPermanent {
                return result.byteSize > 0 || (result.itemCount ?? 0) > 0
            }
            return result.byteSize > 0
        }
    }

    func selectedBytes(staleAfter: TimeInterval, now: Date = Date()) -> UInt64 {
        selectedResults(staleAfter: staleAfter, now: now).reduce(0) { $0 + $1.byteSize }
    }

    /// Rows left unticked by default — warm/hot, unknown age, or strong-confirm — so the footer
    /// explains why the selected total is lower than the reclaimable figure.
    func heldBackCount(staleAfter: TimeInterval, now: Date = Date()) -> Int {
        results.filter { result in
            guard explicitSelection[result.id] == nil else { return false }
            guard !result.target.isPermanent else { return false }
            return !result.isSafeByDefault(staleAfter: staleAfter, now: now)
        }.count
    }

    func selectionSummary(staleAfter: TimeInterval, now: Date = Date()) -> String? {
        let held = heldBackCount(staleAfter: staleAfter, now: now)
        guard held > 0 else { return nil }
        let unknown = results.filter { result in
            explicitSelection[result.id] == nil && result.hasUnknownAge
        }.count
        let noun = held == 1 ? "item" : "items"
        if unknown == held {
            let reason = held == 1 ? "its age is unknown" : "their age is unknown"
            return "\(held) \(noun) left unticked because \(reason)."
        }
        if unknown > 0 {
            return "\(held) \(noun) left unticked (recently touched or age unknown)."
        }
        let pronoun = held == 1 ? "it was" : "they were"
        return "\(held) \(noun) left unticked because \(pronoun) touched recently."
    }
}
