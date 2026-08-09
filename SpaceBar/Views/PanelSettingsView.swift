import SwiftUI

/// Settings live inside the panel rather than a separate window: the panel is a floating
/// `NSPanel`, so a plain window would open behind it, and a menu-bar-only app would have to
/// flip activation policy just to show one.
struct PanelSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.liquidGlassNamespace) private var glassNamespace

    let onBack: () -> Void

    enum Section: String, CaseIterable, Identifiable {
        case appearance
        case limits
        case scanning

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .appearance: "Look"
            case .limits: "Limits"
            case .scanning: "Scanning"
            }
        }
    }

    @State private var section: Section = .appearance

    var body: some View {
        VStack(spacing: 0) {
            header

            Picker("", selection: $section) {
                ForEach(Section.allCases) { section in
                    Text(section.title).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            ScrollView {
                Group {
                    switch section {
                    case .appearance: AppearanceSettingsTab()
                    case .limits: ThresholdSettingsTab()
                    case .scanning: ScanningSettingsTab()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
            }
        }
        .background {
            PanelGlassBackground(cornerRadius: 18)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
            }
            .liquidChipButtonStyle(tint: .accentColor)
            .liquidGlassEffectID("panel-settings-nav", in: glassNamespace)

            Spacer()

            Text("Settings")
                .font(.headline)

            Spacer()

            Button("Reset") {
                settings.resetToDefaults()
            }
            .liquidChipButtonStyle()
            .help("Restore every setting to its default")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }
}
