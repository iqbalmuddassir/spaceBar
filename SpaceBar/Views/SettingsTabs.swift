import SwiftUI

struct ThresholdSettingsTab: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var monitor: DiskSpaceMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsSection(title: "Lifetime") {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ByteFormatting.string(from: settings.lifetimeReclaimedBytes))
                            .font(.headline.monospacedDigit())
                        Text("Reclaimed since you started using SpaceBar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }

            SettingsSection(title: "When to warn you") {
                ThresholdZoneBar(
                    warningFraction: settings.warningFraction,
                    criticalFraction: settings.criticalFraction
                )

                LabeledSlider(
                    label: "Running low below",
                    value: settings.warningFraction,
                    range: AppSettings.warningRange,
                    detail: percentLabel(settings.warningFraction)
                ) { settings.setWarningFraction($0) }

                LabeledSlider(
                    label: "Critically low below",
                    value: settings.criticalFraction,
                    range: AppSettings.criticalRange,
                    detail: percentLabel(settings.criticalFraction)
                ) { settings.setCriticalFraction($0) }

                liveReadout
            }

            SettingsSection(title: "Volume") {
                HStack {
                    Text("Monitoring")
                    Spacer()
                    Text(volumeDescription)
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
        }
    }

    /// Percentages mean nothing without the denominator, so every threshold restates itself
    /// in bytes against the disk actually being watched.
    private var liveReadout: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(thresholdSentence)
            Text(currentSentence)
                .foregroundStyle(monitor.level == .healthy ? Color.secondary : monitor.level.color)
        }
        .font(.caption)
        .padding(.leading, 10)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var thresholdSentence: String {
        guard monitor.totalBytes > 0 else {
            return "Orange below \(percentLabel(settings.warningFraction)), "
                + "red below \(percentLabel(settings.criticalFraction))."
        }
        let warn = bytesLabel(settings.warningFraction)
        let critical = bytesLabel(settings.criticalFraction)
        return "On your \(ByteFormatting.compactFreeSpace(from: monitor.totalBytes)) disk: "
            + "orange below \(warn), red below \(critical)."
    }

    private var currentSentence: String {
        "You have \(monitor.freeSpaceLabel) free right now — \(monitor.level.label.lowercased())."
    }

    private var volumeDescription: String {
        monitor.totalBytes > 0
            ? "Startup disk — \(ByteFormatting.compactFreeSpace(from: monitor.totalBytes))"
            : "Startup disk"
    }

    private func percentLabel(_ fraction: Double) -> String {
        String(format: "%.0f%%", fraction * 100)
    }

    private func bytesLabel(_ fraction: Double) -> String {
        ByteFormatting.compactFreeSpace(from: UInt64(Double(monitor.totalBytes) * fraction))
    }
}

struct LabeledSlider: View {
    let label: String
    let value: Double
    let range: ClosedRange<Double>
    let detail: String
    let onChange: (Double) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.callout)
                .frame(width: 150, alignment: .leading)
            Slider(
                value: Binding(get: { value }, set: onChange),
                in: range
            )
            Text(detail)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
    }
}

/// The control mirrors the bar it configures, so the zones cannot be read in the wrong order.
struct ThresholdZoneBar: View {
    let warningFraction: Double
    let criticalFraction: Double

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                let width = geo.size.width
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.red.opacity(0.35))
                        .frame(width: width * criticalFraction)
                    Rectangle()
                        .fill(Color.orange.opacity(0.32))
                        .frame(width: width * max(0, warningFraction - criticalFraction))
                    Rectangle()
                        .fill(Color.green.opacity(0.28))
                }
            }
            .frame(height: 26)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            HStack {
                Text("0% free")
                Spacer()
                Text("100% free")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}

struct ScanningSettingsTab: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsSection(title: "Call something stale after") {
                HStack(spacing: 12) {
                    Slider(
                        value: Binding(
                            get: { Double(settings.staleDays) },
                            set: { settings.staleDays = Int($0.rounded()) }
                        ),
                        in: Double(AppSettings.staleDayRange.lowerBound)
                            ... Double(AppSettings.staleDayRange.upperBound)
                    )
                    Text(settings.staleDescription)
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 62, alignment: .trailing)
                }

                VStack(alignment: .leading, spacing: 5) {
                    staleEffect("Ages past this turn amber in the list")
                    staleEffect("The review filter reads “\(settings.staleFilterLabel)”")
                    staleEffect("Anything older arrives already ticked")
                }
                .padding(.top, 2)
            }

            SettingsSection(
                title: "Scan these targets",
                footnote: "Unticking skips the scan entirely, which is the fastest way to speed up open."
            ) {
                TargetExclusionList()
            }

            SettingsSection(title: "Behavior") {
                Toggle("Rescan when the panel opens", isOn: $settings.rescanOnOpen)
            }
        }
    }

    private func staleEffect(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Image(systemName: "arrow.turn.down.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct TargetExclusionList: View {
    @EnvironmentObject private var settings: AppSettings

    private var targets: [CleanTarget] {
        CleanTargetRegistry.allTargets().filter { !$0.isPermanent }
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(ReviewableFileCategory.allCases, id: \.self) { category in
                toggle(name: category.title, id: category.settingsID)
            }
            ForEach(targets) { target in
                toggle(name: target.name, id: target.id)
            }
        }
    }

    private func toggle(name: String, id: String) -> some View {
        Toggle(
            name,
            isOn: Binding(
                get: { !settings.isExcluded(targetID: id) },
                set: { settings.setExcluded(!$0, targetID: id) }
            )
        )
        .font(.caption)
        .lineLimit(1)
    }
}
