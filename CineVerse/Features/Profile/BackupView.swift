import SwiftUI
import UniformTypeIdentifiers

public struct CineVerseBackupDocument: FileDocument {
    public static var readableContentTypes: [UTType] { [.json] }

    public var data: Data

    public init(data: Data = Data()) {
        self.data = data
    }

    public init(configuration: ReadConfiguration) throws {
        guard let fileData = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = fileData
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

public struct BackupView: View {
    let container: AppContainer

    @State private var exportDocument: CineVerseBackupDocument?
    @State private var showExporter: Bool = false
    @State private var showImporter: Bool = false

    @State private var pendingImportData: Data?
    @State private var decodedPreview: CineVerseBackup?
    @State private var importMode: BackupImportMode = .merge
    @State private var importReport: BackupImportReport?
    @State private var errorMessage: String?
    @State private var statusBanner: String?

    public init(container: AppContainer) {
        self.container = container
    }

    private static let filenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private var defaultExportFilename: String {
        "CineVerse-Backup-\(Self.filenameDateFormatter.string(from: Date())).json"
    }

    public var body: some View {
        List {
            Section {
                Button {
                    prepareExport()
                } label: {
                    Label("Export Backup (.json)", systemImage: "square.and.arrow.up")
                }

                Button {
                    showImporter = true
                } label: {
                    Label("Import Backup (.json)", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("Local Backup")
            } footer: {
                Text("Backups include your library, tracker progress, watch history, custom collections, direct stream links, and preferences. Local video files remain on this device and are not embedded in JSON backups.")
            }

            if let decodedPreview {
                Section("Ready to Import") {
                    LabeledContent("Exported", value: CineVerseDateFormatters.mediumDisplay.string(from: decodedPreview.exportedAt))
                    LabeledContent("Library Entries", value: "\(decodedPreview.entries.count)")
                    LabeledContent("Collections", value: "\(decodedPreview.collections.count)")
                    LabeledContent("Watch History", value: "\(decodedPreview.history.count)")

                    Picker("Import Mode", selection: $importMode) {
                        ForEach(BackupImportMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Button("Apply Backup") {
                        performImport()
                    }
                    .buttonStyle(CVPrimaryButtonStyle())
                    .frame(maxWidth: .infinity, alignment: .center)

                    Button("Cancel Import", role: .cancel) {
                        pendingImportData = nil
                        self.decodedPreview = nil
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            if let importReport {
                Section("Last Import Summary") {
                    LabeledContent("Entries Imported", value: "\(importReport.entriesImported)")
                    LabeledContent("Progress Records", value: "\(importReport.progressImported)")
                    LabeledContent("History Events", value: "\(importReport.historyImported)")
                    LabeledContent("Collections", value: "\(importReport.collectionsImported)")
                    LabeledContent("Direct Links", value: "\(importReport.directSourcesImported)")

                    if !importReport.skippedLocalFiles.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(
                                "\(importReport.skippedLocalFiles.count) local video file(s) skipped",
                                systemImage: "exclamationmark.triangle.fill"
                            )
                            .font(CVFont.callout.weight(.semibold))
                            .foregroundStyle(CVColor.warning)

                            Text("Local files cannot be transferred inside JSON backups: \(importReport.skippedLocalFiles.joined(separator: ", "))")
                                .font(CVFont.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if let statusBanner {
                Section {
                    Label(statusBanner, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(CVColor.success)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Backup & Restore")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: defaultExportFilename
        ) { result in
            switch result {
            case .success:
                statusBanner = "Backup exported successfully."
                Haptics.notify(.success)
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
            exportDocument = nil
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportedSelection(result)
        }
        .alert("Backup Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func prepareExport() {
        statusBanner = nil
        do {
            let jsonData = try BackupService.exportJSON(
                from: container.modelContainer.mainContext,
                settings: container.settingsStore
            )
            exportDocument = CineVerseBackupDocument(data: jsonData)
            showExporter = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleImportedSelection(_ result: Result<[URL], Error>) {
        statusBanner = nil
        importReport = nil
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                let data = try Data(contentsOf: url)
                let preview = try BackupService.decodeBackup(from: data)
                pendingImportData = data
                decodedPreview = preview
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func performImport() {
        guard let pendingImportData else { return }
        do {
            let report = try BackupService.importBackup(
                data: pendingImportData,
                mode: importMode,
                into: container.modelContainer.mainContext,
                settings: container.settingsStore
            )
            importReport = report
            self.pendingImportData = nil
            decodedPreview = nil
            statusBanner = "Backup restored successfully."
            Haptics.notify(.success)
            Task {
                await container.performBackgroundMaintenance()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
