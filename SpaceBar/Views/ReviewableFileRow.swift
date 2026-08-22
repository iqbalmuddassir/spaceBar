import AppKit
import SwiftUI

struct ReviewableFileRow: View {
    let file: ReviewableFile
    let isSelected: Bool
    let onToggle: () -> Void
    let onReveal: () -> Void

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let rowShape = RoundedRectangle(cornerRadius: 10, style: .continuous)

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                rowContent
            }
            .buttonStyle(.plain)

            revealButton
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            Self.rowShape.fill(backgroundTint)
        }
        .overlay {
            Self.rowShape.strokeBorder(
                isSelected ? Color.accentColor.opacity(0.55) : Color.clear,
                lineWidth: 1
            )
        }
        .contentShape(Self.rowShape)
        .onHover { isHovering = $0 }
        .help(helpText)
        .animation(LiquidGlassMotion.selection(reduceMotion), value: isSelected)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isHovering)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isSelected ? "Marked for deletion" : "Kept")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint("Toggles whether this file is deleted")
        .accessibilityAction(named: "Reveal in Finder", onReveal)
    }

    private var accessibilityLabel: String {
        var parts = [file.displayName, file.subtitleLabel, file.sizeLabel, file.relativeAgeLabel]
        if let location = file.locationLabel {
            parts.append("in \(location)")
        }
        return parts.joined(separator: ", ")
    }

    private var helpText: String {
        [file.url.path, file.regenerationNote]
            .compactMap { $0 }
            .joined(separator: "\n")
    }

    private var backgroundTint: Color {
        if isSelected {
            return .accentColor.opacity(0.16)
        }
        return isHovering ? Color.primary.opacity(0.06) : .clear
    }

    private var rowContent: some View {
        HStack(spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.7))
                .font(.title3)
                .symbolEffect(.bounce, value: isSelected)

            ReviewableFileThumbnail(file: file)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(file.displayName)
                    .font(.system(.body, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 6) {
                    Text(file.subtitleLabel)
                    Text("·")
                    Text(file.relativeAgeLabel)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

                if let location = file.locationLabel {
                    Text(location)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }

            Spacer(minLength: 8)

            Text(file.sizeLabel)
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
                .frame(minWidth: 62, alignment: .trailing)
        }
        .contentShape(Rectangle())
    }

    private var revealButton: some View {
        Button(action: onReveal) {
            Image(systemName: "magnifyingglass")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Reveal in Finder")
        .accessibilityHidden(true)
        .opacity(isHovering ? 1 : 0)
    }
}

private struct ReviewableFileThumbnail: View {
    let file: ReviewableFile
    @State private var image: NSImage?

    private static let maxPixelSize = 128

    var body: some View {
        ZStack {
            Color.primary.opacity(0.06)
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: Self.placeholderSymbol(for: file.kind))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityHidden(true)
        .task(id: file.url) {
            guard file.kind == .screenshot else {
                image = nil
                return
            }
            let url = file.url
            let maxPixelSize = Self.maxPixelSize
            let loaded = await Task.detached(priority: .utility) {
                ThumbnailLoader.thumbnail(for: url, maxPixelSize: maxPixelSize)
            }.value
            guard !Task.isCancelled else { return }
            image = loaded
        }
    }

    private static func placeholderSymbol(for kind: ReviewableFileKind) -> String {
        switch kind {
        case .recording: "video.fill"
        case .installer: "shippingbox.fill"
        case .screenshot: "photo"
        case .buildArtifact: "folder.fill.badge.gearshape"
        }
    }
}
