import SwiftUI

struct AppearanceSettingsTab: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsSection(
                title: "Header",
                footnote: "Every layout has the same checkboxes, ages and one-press cleanup. "
                    + "You are choosing how much room the overview gets, not what the app can do."
            ) {
                HStack(spacing: 7) {
                    ForEach(PanelLayout.allCases) { layout in
                        LayoutPickerCard(
                            layout: layout,
                            isSelected: settings.layout == layout
                        ) {
                            settings.layout = layout
                        }
                    }
                }
            }

            SettingsSection(title: "Menu bar") {
                Picker("Pill style", selection: $settings.pillStyle) {
                    ForEach(PillStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Toggle("Show percentage instead of size", isOn: $settings.showPercentageInPill)
                Toggle("Full color only when critical", isOn: $settings.fullColorOnlyWhenCritical)
            }

            SettingsSection(title: "Row density") {
                Picker("Rows", selection: $settings.density) {
                    ForEach(RowDensity.allCases) { density in
                        Text(density.title).tag(density)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
    }
}

struct LayoutPickerCard: View {
    let layout: PanelLayout
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 7) {
                LayoutThumbnail(layout: layout)
                    .frame(height: 64)
                HStack(spacing: 6) {
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    Text(layout.title)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(layout.summary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.03))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.accentColor : Color.primary.opacity(0.14),
                        lineWidth: isSelected ? 1.6 : 0.8
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

struct LayoutThumbnail: View {
    let layout: PanelLayout

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch layout {
            case .ledger:
                bar(height: 3)
                rows(4)
            case .gauge:
                HStack(spacing: 6) {
                    Circle()
                        .trim(from: 0, to: 0.62)
                        .stroke(Color.accentColor, lineWidth: 3)
                        .rotationEffect(.degrees(-90))
                        .frame(width: 18, height: 18)
                    VStack(alignment: .leading, spacing: 3) {
                        line(width: 0.5)
                        line(width: 0.8, height: 5)
                    }
                }
                rows(2)
            case .map:
                HStack(spacing: 3) {
                    tile(.green).frame(maxWidth: .infinity)
                    VStack(spacing: 3) {
                        tile(.blue)
                        tile(.orange)
                    }
                    .frame(width: 26)
                }
                .frame(height: 28)
                rows(1)
            }
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accentColor.opacity(0.65))
                .frame(height: 7)
        }
        .padding(7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func bar(height: CGFloat) -> some View {
        Capsule().fill(Color.primary.opacity(0.22)).frame(height: height)
    }

    private func rows(_ count: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(0 ..< count, id: \.self) { index in
                line(width: index.isMultiple(of: 2) ? 1 : 0.6)
            }
        }
    }

    private func line(width: CGFloat, height: CGFloat = 4) -> some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.primary.opacity(0.16))
                .frame(width: geo.size.width * width, height: height)
        }
        .frame(height: height)
    }

    private func tile(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(color.opacity(0.35))
            .frame(maxHeight: .infinity)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    var footnote: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
            content
            if let footnote {
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
