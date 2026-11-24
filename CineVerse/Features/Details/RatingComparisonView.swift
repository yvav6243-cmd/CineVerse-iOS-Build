import SwiftUI

private struct RatingBarItem: Identifiable {
    let id: String
    let label: String
    let score: Double
    let tint: Color
}

public struct RatingComparisonView: View {
    let ratings: MultiSourceRatings
    let personalRating: Double?
    let onUpdatePersonalRating: (Double?) -> Void

    @State private var isEditingPersonalScore: Bool = false
    @State private var draftScore: Double = 7.5

    public init(
        ratings: MultiSourceRatings,
        personalRating: Double?,
        onUpdatePersonalRating: @escaping (Double?) -> Void
    ) {
        self.ratings = ratings
        self.personalRating = personalRating
        self.onUpdatePersonalRating = onUpdatePersonalRating
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CVSpacing.sm) {
            headerRow

            if visibleBars.isEmpty && !isEditingPersonalScore {
                Text("No external scores available yet. Tap Rate to add your own 0–10 score.")
                    .font(CVFont.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: CVSpacing.xs + 2) {
                    ForEach(visibleBars) { bar in
                        ratingBarRow(bar)
                    }
                }
            }

            if isEditingPersonalScore {
                personalRatingEditor
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(CVSpacing.md)
        .cvGlass(RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous))
        .padding(.horizontal, CVSpacing.md)
        .onChange(of: personalRating) { _, newValue in
            if !isEditingPersonalScore, let newValue {
                draftScore = newValue
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: CVSpacing.xs) {
            Image(systemName: "chart.bar.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CVColor.ratingGold)

            Text("Ratings")
                .font(CVFont.sectionTitle)
                .foregroundStyle(.primary)

            if let count = ratings.voteCount, count > 0 {
                Text("(\(count.formatted()) votes)")
                    .font(CVFont.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Haptics.selection()
                if !isEditingPersonalScore {
                    draftScore = personalRating ?? 7.5
                }
                withAnimation(CVMotion.snappy) {
                    isEditingPersonalScore.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: personalRating != nil ? "star.fill" : "star")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(CVColor.ratingGold)
                    if let personalRating, personalRating > 0 {
                        Text(String(format: "Your %.1f", personalRating))
                    } else {
                        Text("Rate 0–10")
                    }
                }
                .font(CVFont.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(CVColor.iris.opacity(0.16), in: Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func ratingBarRow(_ item: RatingBarItem) -> some View {
        HStack(spacing: CVSpacing.sm) {
            Text(item.label)
                .font(CVFont.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 82, alignment: .leading)
                .lineLimit(1)

            CVProgressBar(
                fraction: item.score / 10.0,
                height: 7,
                tint: item.tint,
                trackColor: Color.primary.opacity(0.10)
            )

            Text(String(format: "%.1f", item.score))
                .font(CVFont.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .frame(width: 32, alignment: .trailing)
        }
    }

    private var personalRatingEditor: some View {
        VStack(alignment: .leading, spacing: CVSpacing.xs) {
            Divider()
                .padding(.vertical, 2)

            HStack {
                Text("Your Personal Rating")
                    .font(CVFont.callout)
                Spacer()
                Text(draftScore > 0 ? String(format: "%.1f / 10", draftScore) : "Unrated")
                    .font(CVFont.callout.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(CVColor.iris)
            }

            HStack(spacing: CVSpacing.sm) {
                Button {
                    Haptics.selection()
                    draftScore = max(0, draftScore - 0.5)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Slider(value: $draftScore, in: 0...10, step: 0.5)
                    .tint(CVColor.iris)

                Button {
                    Haptics.selection()
                    draftScore = min(10, draftScore + 0.5)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(CVColor.iris)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: CVSpacing.sm) {
                if personalRating != nil {
                    Button("Clear", role: .destructive) {
                        Haptics.impact(.light)
                        onUpdatePersonalRating(nil)
                        withAnimation(CVMotion.snappy) {
                            isEditingPersonalScore = false
                        }
                    }
                    .buttonStyle(CVGlassButtonStyle(compact: true))
                }

                Spacer()

                Button("Cancel") {
                    withAnimation(CVMotion.snappy) {
                        isEditingPersonalScore = false
                    }
                }
                .buttonStyle(CVGlassButtonStyle(compact: true))

                Button("Save Score") {
                    Haptics.notify(.success)
                    onUpdatePersonalRating(draftScore > 0 ? draftScore : nil)
                    withAnimation(CVMotion.snappy) {
                        isEditingPersonalScore = false
                    }
                }
                .buttonStyle(CVPrimaryButtonStyle(compact: true))
            }
        }
    }

    private var visibleBars: [RatingBarItem] {
        var bars: [RatingBarItem] = []
        if let tmdb = ratings.tmdbScore, tmdb > 0 {
            bars.append(RatingBarItem(id: "tmdb", label: "TMDB", score: tmdb, tint: Color(hex: "#01B4E4")))
        }
        if let anilist = ratings.aniListScore, anilist > 0 {
            bars.append(RatingBarItem(id: "anilist", label: "AniList", score: anilist, tint: Color(hex: "#3DB4F2")))
        }
        if let tvmaze = ratings.tvMazeScore, tvmaze > 0 {
            bars.append(RatingBarItem(id: "tvmaze", label: "TVmaze", score: tvmaze, tint: Color(hex: "#3C948B")))
        }
        let composite = ratings.compositeScore
        if composite > 0 {
            bars.append(RatingBarItem(id: "composite", label: "Composite", score: composite, tint: CVColor.ratingGold))
        }
        if let personal = personalRating, personal > 0 {
            bars.append(RatingBarItem(id: "personal", label: "Your Score", score: personal, tint: CVColor.iris))
        }
        return bars
    }
}
