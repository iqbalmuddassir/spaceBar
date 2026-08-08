import Foundation

enum StaleAgeCalculator {
    /// Returns a human label based on the most recently modified item found (sampled).
    static func staleDescription(for urls: [URL], maxSamples: Int = 80) -> String? {
        guard let newest = newestModificationDate(for: urls, maxSamples: maxSamples) else { return nil }
        return relativeAge(from: newest)
    }

    static func newestModificationDate(for urls: [URL], maxSamples: Int = 400) -> Date? {
        let fm = FileManager.default
        var newest: Date?
        var samples = 0

        for url in urls {
            if samples >= maxSamples {
                break
            }
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { continue }

            if let date = modificationDate(of: url) {
                if newest == nil || date > newest! {
                    newest = date
                }
            }
            samples += 1

            guard isDir.boolValue,
                  let enumerator = fm.enumerator(
                      at: url,
                      includingPropertiesForKeys: [.contentModificationDateKey],
                      options: [.skipsHiddenFiles]
                  ) else { continue }

            for case let fileURL as URL in enumerator {
                if samples >= maxSamples {
                    break
                }
                samples += 1
                if let date = modificationDate(of: fileURL) {
                    if newest == nil || date > newest! {
                        newest = date
                    }
                }
            }
        }
        return newest
    }

    private static func modificationDate(of url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    static func relativeAge(from date: Date, now: Date = Date()) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        let minute = 60
        let hour = 60 * minute
        let day = 24 * hour

        if seconds < hour {
            let minutes = max(1, seconds / minute)
            return "last modified \(minutes)m ago"
        }
        if seconds < day {
            let hours = seconds / hour
            return "last modified \(hours)h ago"
        }
        let days = seconds / day
        if days == 1 {
            return "last modified 1d ago"
        }
        return "last modified \(days)d ago"
    }
}
