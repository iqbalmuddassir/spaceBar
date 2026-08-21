import Combine
import Foundation

enum PanelLayout: String, Equatable, CaseIterable, Identifiable {
    case ledger
    case gauge
    case map

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .ledger: "Ledger"
        case .gauge: "Gauge"
        case .map: "Map"
        }
    }

    var summary: String {
        switch self {
        case .ledger: "Thin bar. Most rows visible."
        case .gauge: "Meter and totals up top."
        case .map: "Blocks sized by bytes. Roomiest."
        }
    }
}

enum PillStyle: String, Equatable, CaseIterable, Identifiable {
    case solid
    case tinted

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .solid: "Solid"
        case .tinted: "Tinted"
        }
    }
}

enum RowDensity: String, Equatable, CaseIterable, Identifiable {
    case comfortable
    case compact

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .comfortable: "Comfortable"
        case .compact: "Compact"
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .comfortable: 11
        case .compact: 7
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    enum Key {
        static let layout = "panelLayout"
        static let pillStyle = "pillStyle"
        static let density = "rowDensity"
        static let warningFraction = "warningFraction"
        static let criticalFraction = "criticalFraction"
        static let staleDays = "staleDays"
        static let rescanOnOpen = "rescanOnOpen"
        static let showPercentageInPill = "showPercentageInPill"
        static let fullColorOnlyWhenCritical = "fullColorOnlyWhenCritical"
        static let excludedTargetIDs = "excludedTargetIDs"
        static let lifetimeReclaimedBytes = "lifetimeReclaimedBytes"
        static let hasSeenFirstRunPrimer = "hasSeenFirstRunPrimer"
    }

    enum Default {
        static let layout = PanelLayout.gauge
        static let pillStyle = PillStyle.solid
        static let density = RowDensity.comfortable
        static let warningFraction = 0.20
        static let criticalFraction = 0.10
        static let staleDays = 30
        static let rescanOnOpen = true
        static let showPercentageInPill = false
        /// Off by default so "Solid" means solid at every level, matching the shipped pill.
        /// Turning it on keeps the bar calm until space actually runs out.
        static let fullColorOnlyWhenCritical = false
    }

    static let warningRange: ClosedRange<Double> = 0.05 ... 0.60
    static let criticalRange: ClosedRange<Double> = 0.02 ... 0.40
    static let staleDayRange: ClosedRange<Int> = 1 ... 90

    @Published var layout: PanelLayout {
        didSet { store(layout.rawValue, Key.layout) }
    }

    @Published var pillStyle: PillStyle {
        didSet { store(pillStyle.rawValue, Key.pillStyle) }
    }

    @Published var density: RowDensity {
        didSet { store(density.rawValue, Key.density) }
    }

    @Published var staleDays: Int {
        didSet {
            let clamped = staleDays.clamped(to: Self.staleDayRange)
            if clamped != staleDays {
                staleDays = clamped
                return
            }
            store(staleDays, Key.staleDays)
        }
    }

    @Published var rescanOnOpen: Bool {
        didSet { store(rescanOnOpen, Key.rescanOnOpen) }
    }

    @Published var showPercentageInPill: Bool {
        didSet { store(showPercentageInPill, Key.showPercentageInPill) }
    }

    @Published var fullColorOnlyWhenCritical: Bool {
        didSet { store(fullColorOnlyWhenCritical, Key.fullColorOnlyWhenCritical) }
    }

    @Published var excludedTargetIDs: Set<String> {
        didSet { store(Array(excludedTargetIDs).sorted(), Key.excludedTargetIDs) }
    }

    @Published var hasSeenFirstRunPrimer: Bool {
        didSet { store(hasSeenFirstRunPrimer, Key.hasSeenFirstRunPrimer) }
    }

    /// Every byte ever actually freed by SpaceBar, across every cleanup — a running counter that
    /// only grows, so it stays meaningful even after the disk fills back up.
    @Published private(set) var lifetimeReclaimedBytes: UInt64

    /// Kept ordered by ``clampThresholds()`` so critical can never rise above warning.
    @Published private(set) var warningFraction: Double
    @Published private(set) var criticalFraction: Double

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        layout = defaults.decoded(Key.layout) ?? Default.layout
        pillStyle = defaults.decoded(Key.pillStyle) ?? Default.pillStyle
        density = defaults.decoded(Key.density) ?? Default.density
        warningFraction = defaults.fraction(Key.warningFraction) ?? Default.warningFraction
        criticalFraction = defaults.fraction(Key.criticalFraction) ?? Default.criticalFraction
        staleDays = defaults.integer(forKey: Key.staleDays, fallback: Default.staleDays)
            .clamped(to: Self.staleDayRange)
        rescanOnOpen = defaults.bool(forKey: Key.rescanOnOpen, fallback: Default.rescanOnOpen)
        showPercentageInPill = defaults.bool(
            forKey: Key.showPercentageInPill,
            fallback: Default.showPercentageInPill
        )
        fullColorOnlyWhenCritical = defaults.bool(
            forKey: Key.fullColorOnlyWhenCritical,
            fallback: Default.fullColorOnlyWhenCritical
        )
        excludedTargetIDs = Set(defaults.stringArray(forKey: Key.excludedTargetIDs) ?? [])
        hasSeenFirstRunPrimer = defaults.bool(
            forKey: Key.hasSeenFirstRunPrimer,
            fallback: false
        )
        lifetimeReclaimedBytes = UInt64(defaults.string(forKey: Key.lifetimeReclaimedBytes) ?? "") ?? 0
        clampThresholds()
    }

    /// Test and snapshot seam: an in-memory instance pinned to shipping defaults.
    static func ephemeral() -> AppSettings {
        let suite = UserDefaults(suiteName: "SpaceBar.ephemeral.\(UUID().uuidString)") ?? .standard
        return AppSettings(defaults: suite)
    }

    var staleInterval: TimeInterval {
        Double(staleDays) * RelativeAge.day
    }

    var staleDescription: String {
        staleDays == 1 ? "1 day" : "\(staleDays) days"
    }

    /// Matches the review browser's quick-filter chip, so both read the same number.
    var staleFilterLabel: String {
        "Older than \(staleDays)d"
    }

    func setWarningFraction(_ value: Double) {
        warningFraction = value.clamped(to: Self.warningRange)
        clampThresholds()
        store(warningFraction, Key.warningFraction)
        store(criticalFraction, Key.criticalFraction)
    }

    func setCriticalFraction(_ value: Double) {
        criticalFraction = value.clamped(to: Self.criticalRange)
        clampThresholds()
        store(warningFraction, Key.warningFraction)
        store(criticalFraction, Key.criticalFraction)
    }

    func level(forFreeFraction fraction: Double) -> DiskSpaceLevel {
        if fraction < criticalFraction {
            return .critical
        }
        if fraction < warningFraction {
            return .warning
        }
        return .healthy
    }

    /// Zero is ignored so a no-op delete doesn't churn the store.
    func addReclaimed(_ bytes: UInt64) {
        guard bytes > 0 else { return }
        lifetimeReclaimedBytes += bytes
        store(String(lifetimeReclaimedBytes), Key.lifetimeReclaimedBytes)
    }

    func isExcluded(targetID: String) -> Bool {
        excludedTargetIDs.contains(targetID)
    }

    func setExcluded(_ excluded: Bool, targetID: String) {
        if excluded {
            excludedTargetIDs.insert(targetID)
        } else {
            excludedTargetIDs.remove(targetID)
        }
    }

    func resetToDefaults() {
        layout = Default.layout
        pillStyle = Default.pillStyle
        density = Default.density
        staleDays = Default.staleDays
        rescanOnOpen = Default.rescanOnOpen
        showPercentageInPill = Default.showPercentageInPill
        fullColorOnlyWhenCritical = Default.fullColorOnlyWhenCritical
        excludedTargetIDs = []
        warningFraction = Default.warningFraction
        criticalFraction = Default.criticalFraction
        store(warningFraction, Key.warningFraction)
        store(criticalFraction, Key.criticalFraction)
    }

    /// Critical must stay strictly below warning or the zones render inverted.
    private func clampThresholds() {
        warningFraction = warningFraction.clamped(to: Self.warningRange)
        criticalFraction = criticalFraction.clamped(to: Self.criticalRange)
        if criticalFraction >= warningFraction {
            criticalFraction = max(Self.criticalRange.lowerBound, warningFraction - 0.02)
        }
    }

    private func store(_ value: some Any, _ key: String) {
        defaults.set(value, forKey: key)
    }
}

private extension UserDefaults {
    func decoded<T: RawRepresentable>(_ key: String) -> T? where T.RawValue == String {
        guard let raw = string(forKey: key) else { return nil }
        return T(rawValue: raw)
    }

    func fraction(_ key: String) -> Double? {
        guard object(forKey: key) != nil else { return nil }
        return double(forKey: key)
    }

    func integer(forKey key: String, fallback: Int) -> Int {
        object(forKey: key) == nil ? fallback : integer(forKey: key)
    }

    func bool(forKey key: String, fallback: Bool) -> Bool {
        object(forKey: key) == nil ? fallback : bool(forKey: key)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
