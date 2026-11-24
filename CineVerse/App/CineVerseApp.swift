import SwiftUI
import SwiftData

@main
public struct CineVerseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    @State private var container: AppContainer?
    @State private var startupError: String?
    @State private var showResetConfirmation: Bool = false

    public init() {
        do {
            let modelContainer = try PersistenceController.makeContainer()
            let built = AppContainer(modelContainer: modelContainer)
            _container = State(initialValue: built)
            _startupError = State(initialValue: nil)
            AppDelegate.backgroundRefreshAction = { [built] in
                await built.performBackgroundMaintenance()
            }
        } catch {
            _container = State(initialValue: nil)
            _startupError = State(initialValue: error.localizedDescription)
        }
    }

    public var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    RootTabView(container: container)
                        .environment(container)
                        .modelContainer(container.modelContainer)
                        .preferredColorScheme(container.settingsStore.theme.colorScheme)
                        .onOpenURL { url in
                            DeepLinkRouter.handle(url: url, coordinator: container.coordinator)
                        }
                        .onReceive(NotificationCenter.default.publisher(for: .cineVerseDeepLink)) { note in
                            if let url = note.object as? URL {
                                DeepLinkRouter.handle(url: url, coordinator: container.coordinator)
                            }
                        }
                        .onChange(of: scenePhase) { _, newPhase in
                            if newPhase == .active {
                                Task {
                                    await container.performBackgroundMaintenance()
                                }
                            }
                        }
                } else {
                    databaseRecoveryView
                }
            }
        }
    }

    private var databaseRecoveryView: some View {
        VStack(spacing: CVSpacing.lg) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 52))
                .foregroundStyle(CVColor.danger)

            Text("Local Storage Unavailable")
                .font(CVFont.pageTitle)

            Text(startupError ?? "CineVerse could not open its local SwiftData database.")
                .font(CVFont.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, CVSpacing.xl)

            Button("Reset Local Database") {
                showResetConfirmation = true
            }
            .buttonStyle(CVPrimaryButtonStyle())
            .confirmationDialog(
                "Reset Local Database?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Erase and Recreate Database", role: .destructive) {
                    resetAndReinitialize()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This clears your local library, progress, and preferences stored on this device so CineVerse can start cleanly.")
            }
        }
        .padding()
    }

    private func resetAndReinitialize() {
        do {
            try PersistenceController.resetLocalStore()
            let modelContainer = try PersistenceController.makeContainer()
            let built = AppContainer(modelContainer: modelContainer)
            container = built
            startupError = nil
            AppDelegate.backgroundRefreshAction = { [built] in
                await built.performBackgroundMaintenance()
            }
        } catch {
            startupError = error.localizedDescription
        }
    }
}
