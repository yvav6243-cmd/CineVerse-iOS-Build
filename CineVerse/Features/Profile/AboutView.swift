import SwiftUI

public struct AboutView: View {
    public init() {}

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    public var body: some View {
        List {
            Section {
                VStack(spacing: CVSpacing.xs) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(CVColor.iris)
                        .padding(.bottom, 2)

                    Text("CineVerse")
                        .font(CVFont.pageTitle)

                    Text("Version \(appVersion) (Build \(buildNumber))")
                        .font(CVFont.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, CVSpacing.sm)
            }

            Section("Privacy & Local-First Design") {
                VStack(alignment: .leading, spacing: CVSpacing.xs) {
                    Label("Local-First Storage", systemImage: "lock.shield.fill")
                        .font(CVFont.callout.weight(.semibold))
                        .foregroundStyle(CVColor.success)

                    Text("CineVerse keeps your library, watch history, playback progress, custom collections, and personal ratings entirely on your device. There is zero behavioral tracking, zero analytics telemetry, and your watch history is never uploaded to external servers.")
                        .font(CVFont.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Data Sources & Attributions") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("The Movie Database (TMDB)")
                        .font(CVFont.callout.weight(.semibold))
                    Text("This product uses the TMDB API but is not endorsed or certified by TMDB.")
                        .font(CVFont.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)

                attributionRow(
                    title: "AniList",
                    detail: "Anime catalog metadata and airing schedules provided via the AniList GraphQL API."
                )

                attributionRow(
                    title: "TVmaze",
                    detail: "Television series and broadcast schedule data provided by TVmaze, licensed under CC BY-SA."
                )

                attributionRow(
                    title: "Jikan",
                    detail: "Supplemental anime episode listings provided via the Jikan REST API."
                )

                attributionRow(
                    title: "Internet Archive",
                    detail: "Public-domain films and open media streams discovered via Internet Archive."
                )
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func attributionRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(CVFont.callout.weight(.semibold))
            Text(detail)
                .font(CVFont.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
