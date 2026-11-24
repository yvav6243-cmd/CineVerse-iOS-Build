import SwiftUI
import SwiftData
import PhotosUI
import ImageIO
import UIKit

public struct ProfileView: View {
    let container: AppContainer

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showNameEditor: Bool = false
    @State private var draftName: String = ""
    @State private var isProcessingAvatar: Bool = false
    @State private var avatarErrorMessage: String?

    @State private var completedCount: Int = 0
    @State private var episodesCount: Int = 0
    @State private var hoursWatched: Double = 0
    @State private var collectionsCount: Int = 0

    public init(container: AppContainer) {
        self.container = container
    }

    public var body: some View {
        List {
            profileHeaderSection
            quickStatsSection
            activitySection
            preferencesAndDataSection
            infoSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Profile")
        .onAppear {
            loadSummaryStats()
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await loadAndStoreAvatar(from: newItem)
            }
        }
        .alert("Edit Display Name", isPresented: $showNameEditor) {
            TextField("Display Name", text: $draftName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    container.settingsStore.profileName = trimmed
                }
            }
        } message: {
            Text("Choose the name shown on your local CineVerse profile.")
        }
        .alert("Photo Unavailable", isPresented: Binding(
            get: { avatarErrorMessage != nil },
            set: { if !$0 { avatarErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(avatarErrorMessage ?? "")
        }
    }

    private var profileHeaderSection: some View {
        Section {
            HStack(spacing: CVSpacing.md) {
                avatarView

                VStack(alignment: .leading, spacing: 4) {
                    Text(container.settingsStore.profileName)
                        .font(CVFont.sectionTitle)
                        .foregroundStyle(.primary)

                    Text("Local Profile • On-Device Library")
                        .font(CVFont.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: CVSpacing.sm) {
                        PhotosPicker(
                            selection: $selectedPhotoItem,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Label("Change Photo", systemImage: "photo")
                                .font(CVFont.caption.weight(.semibold))
                        }
                        .buttonStyle(.borderless)

                        if container.settingsStore.avatarData != nil {
                            Button(role: .destructive) {
                                container.settingsStore.avatarData = nil
                            } label: {
                                Text("Remove")
                                    .font(CVFont.caption)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.top, 2)
                }

                Spacer()

                Button {
                    draftName = container.settingsStore.profileName
                    showNameEditor = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CVColor.iris)
                        .frame(width: 34, height: 34)
                        .background(CVColor.iris.opacity(0.14), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit Display Name")
            }
            .padding(.vertical, CVSpacing.xs)
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        ZStack {
            if let data = container.settingsStore.avatarData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [CVColor.iris, CVColor.iris.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                }
            }

            if isProcessingAvatar {
                Color.black.opacity(0.4)
                ProgressView()
                    .tint(.white)
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(Circle())
        .overlay(
            Circle()
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }

    private var quickStatsSection: some View {
        Section("Quick Stats") {
            HStack(spacing: CVSpacing.sm) {
                quickStatPill(title: "Completed", value: "\(completedCount)", symbol: "checkmark.seal.fill", color: CVColor.success)
                quickStatPill(title: "Episodes", value: "\(episodesCount)", symbol: "tv.fill", color: CVColor.iris)
                quickStatPill(title: "Hours", value: String(format: "%.1f", hoursWatched), symbol: "clock.fill", color: CVColor.warning)
                quickStatPill(title: "Lists", value: "\(collectionsCount)", symbol: "rectangle.stack.fill", color: .pink)
            }
            .padding(.vertical, 4)
        }
    }

    private func quickStatPill(title: String, value: String, symbol: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            Text(value)
                .font(CVFont.callout.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.primary)
            Text(title)
                .font(CVFont.micro)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CVSpacing.xs)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: CVRadius.chip, style: .continuous))
    }

    private var activitySection: some View {
        Section("Activity") {
            NavigationLink(value: Route.calendar) {
                Label("Premiere Calendar", systemImage: "calendar.badge.clock")
            }

            NavigationLink(value: Route.history) {
                Label("Watch History", systemImage: "clock.arrow.circlepath")
            }
        }
    }

    private var preferencesAndDataSection: some View {
        Section("Preferences & Data") {
            NavigationLink(value: Route.settings) {
                Label("Settings", systemImage: "gearshape")
            }

            NavigationLink(value: Route.storage) {
                Label("Storage Management", systemImage: "internaldrive")
            }

            NavigationLink(value: Route.backup) {
                Label("Backup & Restore", systemImage: "arrow.up.arrow.down.circle")
            }

            NavigationLink(value: Route.apiKeys) {
                Label("API Keys", systemImage: "key.fill")
            }
        }
    }

    private var infoSection: some View {
        Section {
            NavigationLink(value: Route.about) {
                Label("About CineVerse", systemImage: "info.circle")
            }
        }
    }

    private func loadSummaryStats() {
        let context = container.modelContainer.mainContext
        let entries = container.libraryRepository.allEntries()
        let progress = (try? context.fetch(FetchDescriptor<PlaybackProgressRecord>())) ?? []
        let history = container.progressRepository.watchHistory(limit: nil)
        let snapshot = AnalyticsCalculator.calculate(entries: entries, progress: progress, history: history)

        completedCount = snapshot.totalProjectsWatched
        episodesCount = snapshot.totalEpisodesWatched
        hoursWatched = snapshot.totalHoursWatched
        collectionsCount = container.collectionsRepository.allCollections().count
    }

    private func loadAndStoreAvatar(from item: PhotosPickerItem) async {
        isProcessingAvatar = true
        defer { isProcessingAvatar = false }

        do {
            guard let rawData = try await item.loadTransferable(type: Data.self) else {
                avatarErrorMessage = "The selected image could not be loaded."
                return
            }
            let downsampled = await Task.detached(priority: .userInitiated) {
                Self.downsampleToJPEG(data: rawData, maxPixelSize: 512)
            }.value

            guard let downsampled else {
                avatarErrorMessage = "Unsupported image format."
                return
            }
            container.settingsStore.avatarData = downsampled
            Haptics.notify(.success)
        } catch {
            avatarErrorMessage = error.localizedDescription
        }
    }

    nonisolated private static func downsampleToJPEG(data: Data, maxPixelSize: Int) -> Data? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
            return nil
        }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.85)
    }
}
