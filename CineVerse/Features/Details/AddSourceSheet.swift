import SwiftUI
import UniformTypeIdentifiers

public struct AddSourceSheet: View {
    private enum SourceScope: String, CaseIterable, Identifiable {
        case thisEpisode = "This Episode Only"
        case entireItem = "Entire Series / Item"
        var id: String { rawValue }
    }

    private enum ImporterTarget {
        case video
        case subtitle
    }

    private enum LinkValidationState: Equatable {
        case idle, checking, valid(ValidatedStreamInfo), failed(String)
    }

    @Environment(\.dismiss) private var dismiss

    private let mediaItem: MediaItem
    private let episode: MediaEpisode?
    private let sourceManager: VideoSourceManager
    private let httpClient: HTTPClient
    private let onAdded: () -> Void

    @State private var selectedTab: AddSourceTab
    @State private var scope: SourceScope
    @State private var sourceLabel: String = ""
    @State private var linkURLString: String = ""
    @State private var linkValidation: LinkValidationState = .idle
    @State private var importedVideo: ImportedLocalFileInfo?
    @State private var fileImportError: String?
    @State private var subtitleURLString: String = ""
    @State private var subtitleLanguageCode: String = "en"
    @State private var importedSubtitle: ImportedLocalFileInfo?
    @State private var subtitleError: String?
    @State private var activeImporter: ImporterTarget?
    @State private var isSaving: Bool = false

    public init(
        mediaItem: MediaItem,
        episode: MediaEpisode?,
        sourceManager: VideoSourceManager,
        httpClient: HTTPClient,
        onAdded: @escaping () -> Void
    ) {
        self.init(
            mediaItem: mediaItem,
            episode: episode,
            sourceManager: sourceManager,
            httpClient: httpClient,
            initialTab: .link,
            onAdded: onAdded
        )
    }

    public init(
        mediaItem: MediaItem,
        episode: MediaEpisode?,
        sourceManager: VideoSourceManager,
        httpClient: HTTPClient,
        initialTab: AddSourceTab,
        onAdded: @escaping () -> Void
    ) {
        self.mediaItem = mediaItem
        self.episode = episode
        self.sourceManager = sourceManager
        self.httpClient = httpClient
        self.onAdded = onAdded
        _selectedTab = State(initialValue: initialTab)
        _scope = State(initialValue: episode != nil ? .thisEpisode : .entireItem)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Source Type", selection: $selectedTab) {
                        ForEach(AddSourceTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)

                    if mediaItem.projectType.isEpisodic, let episode {
                        Picker("Attach To", selection: $scope) {
                            Text("This Episode Only (\(episode.formattedCode))").tag(SourceScope.thisEpisode)
                            Text("Entire Series / Item").tag(SourceScope.entireItem)
                        }
                    }

                    TextField("Source Name (optional)", text: $sourceLabel)
                }

                if selectedTab == .link {
                    linkSection
                } else {
                    localFileSection
                }

                optionalSubtitleSection
            }
            .navigationTitle("Add Video Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        cleanupUncommittedFiles()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { Task { await saveSource() } }
                        .fontWeight(.semibold)
                        .disabled(!canSubmit || isSaving)
                }
            }
            .fileImporter(
                isPresented: Binding(
                    get: { activeImporter != nil },
                    set: { if !$0 { activeImporter = nil } }
                ),
                allowedContentTypes: activeImporter == .video ? videoContentTypes : subtitleContentTypes,
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
        }
    }

    private var linkSection: some View {
        Section {
            TextField("https://example.com/stream.m3u8", text: $linkURLString)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .onChange(of: linkURLString) { _, _ in linkValidation = .idle }

            Button { Task { await verifyLink() } } label: {
                HStack {
                    Label("Verify Stream URL", systemImage: "checkmark.shield")
                    Spacer()
                    if linkValidation == .checking { ProgressView().controlSize(.small) }
                }
            }
            .disabled(linkURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || linkValidation == .checking)

            validationFeedbackView
        } header: {
            Text("Direct HTTPS Stream")
        } footer: {
            Text("Supports HTTPS HLS (.m3u8) and direct MP4/MOV/M4V links. Localhost and private IP addresses are blocked.")
        }
    }

    @ViewBuilder
    private var validationFeedbackView: some View {
        switch linkValidation {
        case .idle: EmptyView()
        case .checking:
            HStack(spacing: CVSpacing.xs) {
                ProgressView().controlSize(.small)
                Text("Checking stream syntax and reachability...").font(CVFont.caption).foregroundStyle(.secondary)
            }
        case .valid(let info):
            HStack(alignment: .top, spacing: CVSpacing.xs) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(CVColor.success)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Verified \(info.detectedFormat.badgeText)").font(CVFont.caption.weight(.semibold)).foregroundStyle(CVColor.success)
                    if let contentType = info.contentType, !contentType.isEmpty {
                        Text("Content-Type: \(contentType)").font(CVFont.micro).foregroundStyle(.secondary)
                    }
                }
            }
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(CVFont.caption).foregroundStyle(CVColor.danger)
        }
    }

    private var localFileSection: some View {
        Section {
            Button { activeImporter = .video } label: {
                Label(importedVideo == nil ? "Choose Video File (.mp4, .mov, .m4v)" : "Replace Video File", systemImage: "folder.badge.plus")
            }
            if let importedVideo {
                HStack(spacing: CVSpacing.sm) {
                    Image(systemName: "film.fill").foregroundStyle(CVColor.iris)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(importedVideo.fileName).font(CVFont.callout).lineLimit(1)
                        Text(ByteCountFormatter.string(fromByteCount: importedVideo.byteSize, countStyle: .file))
                            .font(CVFont.micro).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(CVColor.success)
                }
            }
            if let fileImportError {
                Text(fileImportError).font(CVFont.caption).foregroundStyle(CVColor.danger)
            }
        } header: { Text("On-Device Video File") } footer: {
            Text("Selected files are stored privately inside CineVerse and excluded from iCloud backups.")
        }
    }

    private var optionalSubtitleSection: some View {
        Section("Optional Subtitle Track (.srt / .vtt)") {
            Picker("Subtitle Language", selection: $subtitleLanguageCode) {
                ForEach(LanguageCatalog.audioAndSubtitleLanguages) { Text($0.name).tag($0.code) }
            }
            if selectedTab == .link {
                TextField("Subtitle URL (https://.../*.srt or .vtt)", text: $subtitleURLString)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled(true)
                    .onChange(of: subtitleURLString) { _, _ in subtitleError = nil }
            }
            Button { activeImporter = .subtitle } label: {
                Label(importedSubtitle == nil ? "Attach Local Subtitle File (.srt / .vtt)" : "Replace Local Subtitle", systemImage: "captions.bubble")
            }
            if let importedSubtitle {
                HStack {
                    Text(importedSubtitle.fileName).font(CVFont.caption).lineLimit(1)
                    Spacer()
                    Button("Remove", role: .destructive) {
                        LocalVideoStore.shared.deleteFile(relativePath: importedSubtitle.relativePath)
                        self.importedSubtitle = nil
                    }.font(CVFont.caption)
                }
            }
            if let subtitleError {
                Text(subtitleError).font(CVFont.caption).foregroundStyle(CVColor.danger)
            }
        }
    }

    private var canSubmit: Bool {
        switch selectedTab {
        case .link: !linkURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .file: importedVideo != nil
        }
    }

    @discardableResult
    private func verifyLink() async -> URL? {
        switch SourceURLValidator.validateSyntax(linkURLString) {
        case .failure(let error):
            linkValidation = .failed(error.localizedDescription)
            return nil
        case .success(let url):
            linkValidation = .checking
            switch await SourceURLValidator.validateReachability(url: url, httpClient: httpClient) {
            case .success(let info):
                linkValidation = .valid(info)
                return info.url
            case .failure(let error):
                linkValidation = .failed(error.localizedDescription)
                return nil
            }
        }
    }

    private func saveSource() async {
        subtitleError = nil
        isSaving = true
        defer { isSaving = false }

        guard let subtitles = buildStoredSubtitles() else { return }

        let targetSeason = scope == .thisEpisode ? episode?.seasonNumber : nil
        let targetEpisode = scope == .thisEpisode ? episode?.episodeNumber : nil
        let trimmedLabel = sourceLabel.trimmingCharacters(in: .whitespacesAndNewlines)

        switch selectedTab {
        case .link:
            let verifiedURL: URL?
            if case .valid(let info) = linkValidation { verifiedURL = info.url }
            else { verifiedURL = await verifyLink() }
            guard let finalURL = verifiedURL else { return }

            sourceManager.addDirectLinkSource(
                mediaID: mediaItem.id,
                season: targetSeason,
                episode: targetEpisode,
                label: trimmedLabel.isEmpty ? (finalURL.host ?? "Direct Stream") : trimmedLabel,
                url: finalURL,
                subtitles: subtitles
            )

        case .file:
            guard let importedVideo else { return }
            sourceManager.addLocalFileSource(
                mediaID: mediaItem.id,
                season: targetSeason,
                episode: targetEpisode,
                label: trimmedLabel.isEmpty ? importedVideo.fileName : trimmedLabel,
                importedFile: importedVideo,
                subtitles: subtitles
            )
        }

        Haptics.notify(.success)
        onAdded()
        dismiss()
    }

    private func buildStoredSubtitles() -> [StoredSubtitleDTO]? {
        var result: [StoredSubtitleDTO] = []
        let langDisplay = LanguageCatalog.displayName(forLanguageCode: subtitleLanguageCode)

        let rawSubURL = subtitleURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rawSubURL.isEmpty {
            switch SourceURLValidator.validateSubtitleSyntax(rawSubURL) {
            case .failure(let error):
                subtitleError = error.localizedDescription
                return nil
            case .success(let url):
                let format: SubtitleFormat = url.pathExtension.lowercased() == "vtt" ? .webVTT : .srt
                result.append(StoredSubtitleDTO(
                    languageCode: subtitleLanguageCode,
                    displayName: langDisplay,
                    relativePathOrURL: url.absoluteString,
                    formatRaw: format.rawValue
                ))
            }
        }

        if let importedSubtitle {
            let ext = URL(fileURLWithPath: importedSubtitle.fileName).pathExtension.lowercased()
            let format: SubtitleFormat = ext == "vtt" ? .webVTT : .srt
            result.append(StoredSubtitleDTO(
                languageCode: subtitleLanguageCode,
                displayName: "\(langDisplay) (\(importedSubtitle.fileName))",
                relativePathOrURL: importedSubtitle.relativePath,
                formatRaw: format.rawValue
            ))
        }
        return result
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        let target = activeImporter
        activeImporter = nil

        switch result {
        case .failure(let error):
            if target == .video { fileImportError = error.localizedDescription }
            else { subtitleError = error.localizedDescription }
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                if target == .video {
                    fileImportError = nil
                    let previous = importedVideo
                    importedVideo = try LocalVideoStore.shared.importVideo(from: url)
                    if let previous { LocalVideoStore.shared.deleteFile(relativePath: previous.relativePath) }
                } else if target == .subtitle {
                    subtitleError = nil
                    let previous = importedSubtitle
                    importedSubtitle = try LocalVideoStore.shared.importSubtitle(from: url)
                    if let previous { LocalVideoStore.shared.deleteFile(relativePath: previous.relativePath) }
                }
            } catch {
                if target == .video { fileImportError = error.localizedDescription }
                else { subtitleError = error.localizedDescription }
            }
        }
    }

    private func cleanupUncommittedFiles() {
        if let importedVideo { LocalVideoStore.shared.deleteFile(relativePath: importedVideo.relativePath) }
        if let importedSubtitle { LocalVideoStore.shared.deleteFile(relativePath: importedSubtitle.relativePath) }
    }

    private var videoContentTypes: [UTType] {
        var types: [UTType] = [.movie, .mpeg4Movie, .quickTimeMovie]
        if let m4v = UTType(filenameExtension: "m4v") { types.append(m4v) }
        return types
    }

    private var subtitleContentTypes: [UTType] {
        var types: [UTType] = [.plainText]
        if let srt = UTType(filenameExtension: "srt") { types.append(srt) }
        if let vtt = UTType(filenameExtension: "vtt") { types.append(vtt) }
        return types
    }
}
