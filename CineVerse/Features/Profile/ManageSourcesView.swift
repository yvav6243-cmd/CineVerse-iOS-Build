import SwiftUI

public struct ManageSourcesView: View {
    let sourceManager: VideoSourceManager
    let httpClient: HTTPClient

    @State private var userSources: [UserVideoSourceDTO] = []
    @State private var providerStates: [String: Bool] = [:]
    @State private var testURLString: String = ""
    @State private var testResultText: String?
    @State private var testIsSuccess: Bool = false
    @State private var isTestingURL: Bool = false

    public init(sourceManager: VideoSourceManager, httpClient: HTTPClient) {
        self.sourceManager = sourceManager
        self.httpClient = httpClient
    }

    public var body: some View {
        Form {
            Section {
                if userSources.isEmpty {
                    Text("No custom stream URLs or imported video files yet. Open any movie or episode and tap Add Source to attach your own HLS (.m3u8), MP4, WebM, DASH, or local file.")
                        .font(CVFont.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(userSources, id: \.id) { src in
                        HStack(spacing: CVSpacing.sm) {
                            Image(systemName: src.kindRaw == UserVideoSourceKind.localFile.rawValue ? "doc.fill" : "link")
                                .foregroundStyle(CVColor.iris)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(src.label)
                                    .font(CVFont.cardTitle)
                                    .lineLimit(1)
                                HStack(spacing: 4) {
                                    Text(src.mediaID)
                                    if let s = src.season, let e = src.episode {
                                        Text("· S\(s) E\(e)")
                                    }
                                    if !src.subtitles.isEmpty {
                                        Text("· \(src.subtitles.count) Sub")
                                    }
                                }
                                .font(CVFont.micro)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            }
                            Spacer()
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                sourceManager.deleteUserSource(uuid: src.id)
                                reloadData()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            } header: {
                Text("My Added Video Sources (\(userSources.count))")
            }

            Section {
                ForEach(SourceProviderPreferences.configurableProviders) { info in
                    Toggle(isOn: Binding(
                        get: { providerStates[info.id] ?? true },
                        set: { newVal in
                            providerStates[info.id] = newVal
                            SourceProviderPreferences.setEnabled(newVal, for: info.id)
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(info.title)
                                .font(CVFont.callout)
                            Text(info.subtitle)
                                .font(CVFont.micro)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(CVColor.iris)
                }
            } header: {
                Text("Legal & Open Video Source Integrations")
            } footer: {
                Text("CineVerse respects platform protections and never bypasses DRM. Disable any source you do not want queried during playback setup.")
            }

            Section("Stream Compatibility Checker") {
                TextField("https://example.com/master.m3u8", text: $testURLString)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button {
                    Task { await verifyTestURL() }
                } label: {
                    HStack {
                        Label("Check Format & Reachability", systemImage: "checkmark.shield")
                        Spacer()
                        if isTestingURL {
                            ProgressView().controlSize(.small)
                        }
                    }
                }
                .disabled(testURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTestingURL)

                if let testResultText {
                    Label(testResultText, systemImage: testIsSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(CVFont.caption)
                        .foregroundStyle(testIsSuccess ? CVColor.success : CVColor.danger)
                }
            }
        }
        .navigationTitle("Video Sources & Providers")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { reloadData() }
    }

    private func reloadData() {
        userSources = sourceManager.allUserSources()
        var map: [String: Bool] = [:]
        for info in SourceProviderPreferences.configurableProviders {
            map[info.id] = SourceProviderPreferences.isEnabled(providerID: info.id)
        }
        providerStates = map
    }

    private func verifyTestURL() async {
        isTestingURL = true
        defer { isTestingURL = false }
        switch SourceURLValidator.validateSyntax(testURLString) {
        case .failure(let err):
            testIsSuccess = false
            testResultText = err.localizedDescription
        case .success(let url):
            switch await SourceURLValidator.validateReachability(url: url, httpClient: httpClient) {
            case .failure(let err):
                testIsSuccess = false
                testResultText = err.localizedDescription
            case .success(let info):
                testIsSuccess = true
                testResultText = "Compatible \(info.detectedFormat.rawValue) (\(info.contentType ?? "stream"))"
            }
        }
    }
}
