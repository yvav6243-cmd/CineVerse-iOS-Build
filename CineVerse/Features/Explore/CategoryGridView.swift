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

    public static func accentHex(for category: MediaProjectType) -> String {
        switch category {
        case .movie: return "#6E5BFF"
        case .anime: return "#FF375F"
        case .animeMovie: return "#BF5AF2"
        case .tvSeries: return "#0A84FF"
        case .cartoonSeries: return "#FF9F0A"
        case .cartoonMovie: return "#F59E0B"
        case .drama: return "#FF6482"
        case .documentary: return "#30D158"
        case .shortFilm: return "#0D9488"
        case .indieFestival: return "#DB2777"
        case .special: return "#0EA5E9"
        case .other: return "#AC8E68"
        }
    }

    private func accentColor(for category: MediaProjectType) -> Color {
        Color(hex: Self.accentHex(for: category))
    }
}
