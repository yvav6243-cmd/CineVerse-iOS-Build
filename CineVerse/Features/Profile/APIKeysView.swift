import SwiftUI

public struct APIKeysView: View {
    let tmdbService: TMDBServiceProtocol

    @State private var credentialInput: String = ""
    @State private var isValidating: Bool = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var hasKeychainKey: Bool = false
    @State private var hasAnyCredential: Bool = false

    public init(tmdbService: TMDBServiceProtocol) {
        self.tmdbService = tmdbService
    }

    private var statusTitle: String {
        if hasKeychainKey {
            return "Configured (Keychain)"
        }
        if hasAnyCredential {
            return "Configured (Build Config)"
        }
        return "Not Set"
    }

    private var statusColor: Color {
        if hasAnyCredential {
            return CVColor.success
        }
        return CVColor.warning
    }

    public var body: some View {
        Form {
            Section("TMDB Status") {
                HStack {
                    Text("Current Source")
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(statusTitle)
                            .font(CVFont.callout.weight(.semibold))
                            .foregroundStyle(statusColor)
                    }
                }
            }

            Section("TMDB Credential") {
                SecureField("API Key (v3) or Read Access Token (v4)", text: $credentialInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button {
                    Task {
                        await verifyAndSave()
                    }
                } label: {
                    HStack {
                        if isValidating {
                            ProgressView()
                                .padding(.trailing, 6)
                        }
                        Text(isValidating ? "Verifying…" : "Verify & Save")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(
                    isValidating ||
                    credentialInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )

                if hasKeychainKey {
                    Button("Remove Key", role: .destructive) {
                        removeKeychainKey()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            if let statusMessage {
                Section {
                    Label(statusMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(CVColor.success)
                }
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(CVColor.danger)
                }
            }

            Section("How to Get a Free TMDB Key") {
                VStack(alignment: .leading, spacing: CVSpacing.xs) {
                    Text("1. Create or sign in to a free account at themoviedb.org.")
                    Text("2. Open Account Settings → API and create an API key (Developer / Personal).")
                    Text("3. Copy either your API Key (v3 auth) or API Read Access Token (v4 auth) and paste it above.")
                    Text("4. Your credential is stored securely in the iOS Keychain on this device only.")
                }
                .font(CVFont.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)

                Text("AniList, TVmaze, Jikan, and Internet Archive catalogs work automatically with no API key required.")
                    .font(CVFont.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("API Keys")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshStatus()
        }
    }

    private func refreshStatus() {
        hasKeychainKey = SecretsProvider.hasKeychainTMDBCredential()
        hasAnyCredential = SecretsProvider.tmdbCredential() != nil
    }

    private func verifyAndSave() async {
        let trimmed = credentialInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isValidating = true
        errorMessage = nil
        statusMessage = nil
        defer { isValidating = false }

        do {
            try await tmdbService.validateCredential(trimmed)
            try SecretsProvider.saveTMDBCredential(trimmed)
            credentialInput = ""
            refreshStatus()
            statusMessage = "TMDB key verified and saved to Keychain."
            Haptics.notify(.success)
        } catch {
            errorMessage = error.localizedDescription
            Haptics.notify(.error)
        }
    }

    private func removeKeychainKey() {
        errorMessage = nil
        statusMessage = nil
        do {
            try SecretsProvider.removeTMDBCredential()
            refreshStatus()
            statusMessage = "Saved Keychain credential removed."
            Haptics.selection()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
