import SwiftUI

public struct FilterSheetView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: CatalogFilterCriteria
    @State private var availableGenres: [String] = []
    @State private var isLoadingGenres: Bool = false

    private let catalogRepository: CatalogRepositoryProtocol
    private let settingsStore: SettingsStore
    private let onApply: (CatalogFilterCriteria) -> Void

    private let durationOptions: [(label: String, value: Int?)] = [
        ("Any", nil),
        ("30m or less", 30),
        ("60m or less", 60),
        ("90m or less", 90),
        ("120m or less", 120),
        ("180m or less", 180)
    ]

    private let seasonsOptions: [(label: String, value: Int?)] = [
        ("Any", nil),
        ("1+ Seasons", 1),
        ("2+ Seasons", 2),
        ("3+ Seasons", 3),
        ("5+ Seasons", 5)
    ]

    public init(
        initialCriteria: CatalogFilterCriteria,
        catalogRepository: CatalogRepositoryProtocol,
        settingsStore: SettingsStore,
        onApply: @escaping (CatalogFilterCriteria) -> Void
    ) {
        self._draft = State(initialValue: initialCriteria)
        self.catalogRepository = catalogRepository
        self.settingsStore = settingsStore
        self.onApply = onApply
    }

    private var yearOptions: [Int] {
        let maxYear = Calendar.current.component(.year, from: Date()) + 2
        return Array((1900...maxYear).reversed())
    }

    public var body: some View {
        NavigationStack {
            Form {
                categorySection
                genresSection
                releaseSection
                regionLanguageSection
                ratingAndLengthSection
                searchOptionsSection
            }
            .navigationTitle("Catalog Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        Haptics.selection()
                        draft.reset()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        Haptics.impact(.light)
                        onApply(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .task(id: draft.selectedCategory) {
                await loadGenres()
            }
        }
    }

    private var categorySection: some View {
        Section("Category") {
            Picker("Category", selection: $draft.selectedCategory) {
                Text("All Categories").tag(MediaProjectType?.none)
                ForEach(MediaProjectType.allCases) { type in
                    Label(type.pluralTitle, systemImage: type.symbolName)
                        .tag(MediaProjectType?.some(type))
                }
            }
        }
    }

    private var genresSection: some View {
        Section {
            if isLoadingGenres && availableGenres.isEmpty {
                HStack(spacing: CVSpacing.sm) {
                    ProgressView()
                    Text("Loading genres...")
                        .font(CVFont.caption)
                        .foregroundStyle(.secondary)
                }
            } else if availableGenres.isEmpty {
                Text("No genre list available")
                    .font(CVFont.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 132), spacing: CVSpacing.xs)],
                    alignment: .leading,
                    spacing: CVSpacing.xs
                ) {
                    ForEach(availableGenres, id: \.self) { genre in
                        let selected = draft.selectedGenres.contains(genre)
                        FilterChip(title: genre, isSelected: selected) {
                            if selected {
                                draft.selectedGenres.remove(genre)
                            } else {
                                draft.selectedGenres.insert(genre)
                            }
                        }
                    }
                }
                .padding(.vertical, CVSpacing.xxs)
            }
        } header: {
            HStack {
                Text("Genres")
                Spacer()
                if !draft.selectedGenres.isEmpty {
                    Text("\(draft.selectedGenres.count) selected")
                        .font(CVFont.caption)
                        .foregroundStyle(CVColor.iris)
                }
            }
        }
    }

    private var releaseSection: some View {
        Section("Release") {
            Picker("Year From", selection: Binding(
                get: { draft.yearFrom },
                set: { newValue in
                    draft.yearFrom = newValue
                    if let from = newValue, let to = draft.yearTo, from > to {
                        draft.yearTo = from
                    }
                }
            )) {
                Text("Any").tag(Int?.none)
                ForEach(yearOptions, id: \.self) { year in
                    Text(String(year)).tag(Int?.some(year))
                }
            }

            Picker("Year To", selection: Binding(
                get: { draft.yearTo },
                set: { newValue in
                    draft.yearTo = newValue
                    if let to = newValue, let from = draft.yearFrom, to < from {
                        draft.yearFrom = to
                    }
                }
            )) {
                Text("Any").tag(Int?.none)
                ForEach(yearOptions, id: \.self) { year in
                    Text(String(year)).tag(Int?.some(year))
                }
            }

            Picker("Release Status", selection: $draft.releaseStatus) {
                Text("Any").tag(MediaReleaseStatus?.none)
                ForEach(MediaReleaseStatus.allCases) { status in
                    Text(status.rawValue).tag(MediaReleaseStatus?.some(status))
                }
            }
        }
    }

    private var regionLanguageSection: some View {
        Section("Origin & Language") {
            Picker("Country", selection: $draft.country) {
                Text("Any").tag(String?.none)
                ForEach(LanguageCatalog.countries) { country in
                    Text(country.name).tag(String?.some(country.code))
                }
            }

            Picker("Language", selection: $draft.language) {
                Text("Any").tag(String?.none)
                ForEach(LanguageCatalog.audioAndSubtitleLanguages) { lang in
                    Text(lang.name).tag(String?.some(lang.code))
                }
            }
        }
    }

    private var ratingAndLengthSection: some View {
        Section("Score & Format") {
            VStack(alignment: .leading, spacing: CVSpacing.xs) {
                HStack {
                    Text("Minimum Rating")
                    Spacer()
                    Text(draft.minimumRating > 0 ? String(format: "%.1f+", draft.minimumRating) : "Any")
                        .font(CVFont.callout)
                        .foregroundStyle(draft.minimumRating > 0 ? CVColor.iris : .secondary)
                        .monospacedDigit()
                }
                Slider(value: $draft.minimumRating, in: 0...9.5, step: 0.5)
                    .tint(CVColor.iris)
            }

            Picker("Max Duration", selection: $draft.maxDurationMinutes) {
                ForEach(durationOptions, id: \.label) { option in
                    Text(option.label).tag(option.value)
                }
            }

            Picker("Min Seasons", selection: $draft.minSeasonsCount) {
                ForEach(seasonsOptions, id: \.label) { option in
                    Text(option.label).tag(option.value)
                }
            }
        }
    }

    private var searchOptionsSection: some View {
        Section("Title Matching") {
            Toggle("Search Original Title Only", isOn: $draft.searchByOriginalTitleOnly)
                .tint(CVColor.iris)
        }
    }

    private func loadGenres() async {
        isLoadingGenres = true
        let fetched = await catalogRepository.genres(
            for: draft.selectedCategory,
            language: settingsStore.contentLanguageCode
        )
        availableGenres = fetched
        isLoadingGenres = false
    }
}
