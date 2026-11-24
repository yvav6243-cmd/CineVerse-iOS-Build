import SwiftUI

public struct CategoryGridView: View {
    let onSelectCategory: (MediaProjectType) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: CVSpacing.sm),
        GridItem(.flexible(), spacing: CVSpacing.sm)
    ]

    public init(onSelectCategory: @escaping (MediaProjectType) -> Void) {
        self.onSelectCategory = onSelectCategory
    }

    public var body: some View {
        LazyVGrid(columns: columns, spacing: CVSpacing.sm) {
            ForEach(MediaProjectType.allCases) { category in
                categoryTile(for: category)
            }
        }
        .padding(.horizontal, CVSpacing.md)
    }

    private func categoryTile(for category: MediaProjectType) -> some View {
        let tint = accentColor(for: category)

        return Button {
            Haptics.selection()
            onSelectCategory(category)
        } label: {
            HStack(spacing: CVSpacing.sm) {
                Image(systemName: category.symbolName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.pluralTitle)
                        .font(CVFont.cardTitle)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(category.isEpisodic ? "Episodic" : "Feature")
                        .font(CVFont.micro)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(CVSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cvGlass(RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous), interactive: true)
        }
        .buttonStyle(.plain)
    }

    private func accentColor(for category: MediaProjectType) -> Color {
        switch category {
        case .movie: return CVColor.iris
        case .anime: return Color(hex: "#FF375F")
        case .animeMovie: return Color(hex: "#BF5AF2")
        case .tvSeries: return Color(hex: "#0A84FF")
        case .cartoonSeries: return Color(hex: "#FF9F0A")
        case .cartoonMovie: return Color(hex: "#FFD60A")
        case .drama: return Color(hex: "#FF6482")
        case .documentary: return Color(hex: "#30D158")
        case .special: return Color(hex: "#64D2FF")
        case .other: return Color(hex: "#AC8E68")
        }
    }
}
