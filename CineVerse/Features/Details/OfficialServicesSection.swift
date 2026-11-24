import SwiftUI

public struct OfficialServicesSection: View {
    let links: [ExternalOfficialPlatformLink]
    @Binding var pendingExternalURL: URL?

    public init(
        links: [ExternalOfficialPlatformLink],
        pendingExternalURL: Binding<URL?>
    ) {
        self.links = links
        self._pendingExternalURL = pendingExternalURL
    }

    private var safeLinks: [ExternalOfficialPlatformLink] {
        links.filter { $0.url.scheme?.lowercased() == "https" }
    }

    public var body: some View {
        if !safeLinks.isEmpty {
            VStack(alignment: .leading, spacing: CVSpacing.sm) {
                SectionHeader(
                    title: "Where to Watch",
                    subtitle: "Licensed official streaming platforms",
                    symbolName: "safari",
                    actionTitle: nil
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: CVSpacing.sm) {
                        ForEach(safeLinks) { link in
                            serviceButton(link)
                        }
                    }
                    .padding(.horizontal, CVSpacing.md)
                }
            }
        }
    }

    private func serviceButton(_ link: ExternalOfficialPlatformLink) -> some View {
        Button {
            Haptics.selection()
            pendingExternalURL = link.url
        } label: {
            HStack(spacing: CVSpacing.sm) {
                Image(systemName: "play.rectangle.on.rectangle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CVColor.iris)
                    .frame(width: 34, height: 34)
                    .background(CVColor.iris.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Open in \(link.siteName)")
                        .font(CVFont.cardTitle)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(link.url.host ?? "Official Site")
                        if let lang = link.languageCode, !lang.isEmpty {
                            Text("•")
                            Text(LanguageCatalog.displayName(forLanguageCode: lang))
                        }
                    }
                    .font(CVFont.micro)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                Image(systemName: "arrow.up.right.square")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, CVSpacing.sm)
            .padding(.vertical, CVSpacing.xs + 2)
            .cvGlass(RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous), interactive: true)
        }
        .buttonStyle(.plain)
    }
}
