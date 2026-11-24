import SwiftUI

public struct StorageManagementView: View {
    let responseCache: ResponseDiskCache

    @State private var imageCacheBytes: Int64 = 0
    @State private var responseCacheBytes: Int64 = 0
    @State private var urlCacheBytes: Int64 = 0
    @State private var videosBytes: Int64 = 0
    @State private var subtitlesBytes: Int64 = 0
    @State private var availableDeviceBytes: Int64 = 0
    @State private var videoFiles: [(relativePath: String, fileName: String, sizeBytes: Int64)] = []
    @State private var filePendingDelete: (relativePath: String, fileName: String, sizeBytes: Int64)?

    public init(responseCache: ResponseDiskCache) {
        self.responseCache = responseCache
    }

    public var body: some View {
        List {
            Section("Device Storage") {
                LabeledContent("Available Space", value: formattedBytes(availableDeviceBytes))
                LabeledContent(
                    "Total App Media & Cache",
                    value: formattedBytes(imageCacheBytes + responseCacheBytes + urlCacheBytes + videosBytes + subtitlesBytes)
                )
            }

            Section("Caches") {
                cacheRow(
                    title: "Image Cache",
                    subtitle: "Cached posters, backdrops & stills",
                    bytes: imageCacheBytes
                ) {
                    Task {
                        await ImagePipeline.shared.clearDiskCache()
                        await refreshSizes()
                        Haptics.notify(.success)
                    }
                }

                cacheRow(
                    title: "Catalog & Metadata Cache",
                    subtitle: "Offline catalog responses",
                    bytes: responseCacheBytes
                ) {
                    Task {
                        await responseCache.clear()
                        await refreshSizes()
                        Haptics.notify(.success)
                    }
                }

                cacheRow(
                    title: "Network URL Cache",
                    subtitle: "HTTP response disk buffer",
                    bytes: urlCacheBytes
                ) {
                    URLCache.shared.removeAllCachedResponses()
                    Task {
                        await refreshSizes()
                        Haptics.notify(.success)
                    }
                }
            }

            Section("Subtitles") {
                cacheRow(
                    title: "Imported Subtitles",
                    subtitle: "Local .srt and .vtt files",
                    bytes: subtitlesBytes
                ) {
                    LocalVideoStore.shared.clearSubtitles()
                    Task {
                        await refreshSizes()
                        Haptics.notify(.success)
                    }
                }
            }

            Section("Imported Local Videos (\(formattedBytes(videosBytes)))") {
                if videoFiles.isEmpty {
                    Text("No local video files stored in CineVerse.")
                        .font(CVFont.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(videoFiles, id: \.relativePath) { file in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.fileName)
                                    .font(CVFont.callout)
                                    .lineLimit(1)
                                Text(formattedBytes(file.sizeBytes))
                                    .font(CVFont.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                filePendingDelete = file
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(CVColor.danger)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Delete \(file.fileName)")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Storage Management")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refreshSizes()
        }
        .refreshable {
            await refreshSizes()
        }
        .confirmationDialog(
            "Delete Video File?",
            isPresented: Binding(
                get: { filePendingDelete != nil },
                set: { if !$0 { filePendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete File", role: .destructive) {
                if let file = filePendingDelete {
                    LocalVideoStore.shared.deleteFile(relativePath: file.relativePath)
                    filePendingDelete = nil
                    Task {
                        await refreshSizes()
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                filePendingDelete = nil
            }
        } message: {
            if let file = filePendingDelete {
                Text("This permanently deletes \(file.fileName) (\(formattedBytes(file.sizeBytes))) from CineVerse storage.")
            }
        }
    }

    private func cacheRow(
        title: String,
        subtitle: String,
        bytes: Int64,
        clearAction: @escaping () -> Void
    ) -> some View {
        HStack(spacing: CVSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(CVFont.callout.weight(.medium))
                Text(subtitle)
                    .font(CVFont.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(formattedBytes(bytes))
                .font(CVFont.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Button("Clear", action: clearAction)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(bytes == 0)
        }
    }

    private func refreshSizes() async {
        imageCacheBytes = await ImagePipeline.shared.diskSizeBytes()
        responseCacheBytes = await responseCache.sizeBytes()
        urlCacheBytes = Int64(URLCache.shared.currentDiskUsage)
        videosBytes = LocalVideoStore.shared.totalVideosSizeBytes()
        subtitlesBytes = LocalVideoStore.shared.totalSubtitlesSizeBytes()
        videoFiles = LocalVideoStore.shared.listVideoFiles()
        availableDeviceBytes = computeAvailableDeviceSpace()
    }

    private func computeAvailableDeviceSpace() -> Int64 {
        let homeURL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        if let values = try? homeURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let capacity = values.volumeAvailableCapacityForImportantUsage {
            return capacity
        }
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let free = attrs[.systemFreeSize] as? NSNumber {
            return free.int64Value
        }
        return 0
    }

    private func formattedBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: max(bytes, 0), countStyle: .file)
    }
}
