import Foundation

enum CleanupActivity: String, Equatable, CaseIterable {
    case used
    case built
    case downloaded
    case emptied
    case captured
    case recorded
    case booted
    case installed
    case trashed

    var verb: String {
        switch self {
        case .used: "Last used"
        case .built: "Built"
        case .downloaded: "Downloaded"
        case .emptied: "Emptied"
        case .captured: "Captured"
        case .recorded: "Recorded"
        case .booted: "Booted"
        case .installed: "Installed"
        case .trashed: "Newest item trashed"
        }
    }

    /// States what cleaning would cost, rather than restating the age the caption already gave.
    var freshCaution: String {
        switch self {
        case .used: "in active use"
        case .built: "forces a full rebuild"
        case .downloaded: "will re-download"
        case .emptied: "just emptied"
        case .captured, .recorded: "you may still need these"
        case .booted: "simulator still in use"
        case .installed: "just installed"
        case .trashed: "added today"
        }
    }
}

enum RecencyTemperature: Equatable {
    case hot
    case warm
    case cold

    var isSafeByDefault: Bool {
        self == .cold
    }
}

struct Recency: Equatable {
    let activity: CleanupActivity
    let lastTouched: Date

    func temperature(staleAfter: TimeInterval, now: Date = Date()) -> RecencyTemperature {
        let age = max(0, now.timeIntervalSince(lastTouched))
        if age < RelativeAge.day {
            return .hot
        }
        return age >= staleAfter ? .cold : .warm
    }

    func phrase(now: Date = Date()) -> String {
        "\(activity.verb) \(RelativeAge.string(from: lastTouched, now: now))"
    }

    func caption(staleAfter: TimeInterval, now: Date = Date()) -> String {
        let base = phrase(now: now)
        guard temperature(staleAfter: staleAfter, now: now) == .hot else { return base }
        return "\(base) — \(activity.freshCaution)"
    }
}

enum RelativeAge {
    static let minute: TimeInterval = 60
    static let hour: TimeInterval = 60 * minute
    static let day: TimeInterval = 24 * hour
    static let week: TimeInterval = 7 * day
    static let month: TimeInterval = 30 * day
    static let year: TimeInterval = 365 * day

    static func string(from date: Date, now: Date = Date()) -> String {
        let seconds = max(0, now.timeIntervalSince(date))

        if seconds < minute {
            return "just now"
        }
        if seconds < hour {
            return countPhrase(seconds / minute, unit: "minute")
        }
        if seconds < day {
            return countPhrase(seconds / hour, unit: "hour")
        }
        if seconds < week {
            return countPhrase(seconds / day, unit: "day")
        }
        if seconds < month {
            return countPhrase(seconds / week, unit: "week")
        }
        if seconds < year {
            return countPhrase(seconds / month, unit: "month")
        }
        return countPhrase(seconds / year, unit: "year")
    }

    private static func countPhrase(_ value: Double, unit: String) -> String {
        let count = max(1, Int(value))
        let plural = count == 1 ? unit : "\(unit)s"
        return "\(count) \(plural) ago"
    }
}
