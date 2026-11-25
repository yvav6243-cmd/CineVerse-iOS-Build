import SwiftUI

public struct CastRailView: View {
    let cast: [MediaCreditPerson]

    public init(cast: [MediaCreditPerson]) {
        self.cast = cast
    }

    public var body: some View {
        if !cast.isEmpty {
            VStack(alignment: .leading, spacing: CVSpacing.sm) {
                SectionHeader(
                    title: "Cast & Voice Actors",
                    symbolName: "person.2.fill",
                    actionTitle: nil
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: CVSpacing.sm) {
                        ForEach(cast) { person in
                            castCard(person)
                        }
                    }
                    .padding(.horizontal, CVSpacing.md)
                }
            }
        }
    }

    private func castCard(_ person: MediaCreditPerson) -> some View {
        VStack(spacing: CVSpacing.xs) {
            CachedAsyncImage(
                url: person.profileImageURL,
                targetSize: CGSize(width: 140, height: 140),
                fallbackSymbol: "person.fill"
            )
            .frame(width: 62, height: 62)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.75)
            )
            .shadow(color: Color.black.opacity(0.14), radius: 5, x: 0, y: 3)

            VStack(spacing: 2) {
                Text(person.name)
                    .font(CVFont.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                if !person.roleOrCharacter.isEmpty {
                    Text(person.roleOrCharacter)
                        .font(CVFont.micro)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(width: 76)
    }
}
