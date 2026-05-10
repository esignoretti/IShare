import SwiftUI

@main
struct IShareApp: App {
    @StateObject private var configStore = ConfigStore()
    @State private var showShareSheet = false
    @State private var pendingFileURL: URL?

    var body: some Scene {
        WindowGroup {
            if configStore.isConfigured {
                MainContentView(
                    configStore: configStore,
                    onShareFile: { url in
                        pendingFileURL = url
                        showShareSheet = true
                    }
                )
                .environmentObject(configStore)
                .sheet(isPresented: $showShareSheet) {
                    if let url = pendingFileURL {
                        ShareSheetView(fileURL: url, configStore: configStore)
                    }
                }
            } else {
                ConfigView()
            }
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .appSettings) {
                Button("S3 Configuration...") {
                    openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandGroup(before: .newItem) {
                Button("Share File...") {
                    openFilePicker()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }
    }

    private func openSettings() {
        let settingsView = SettingsView(configStore: configStore)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "S3 Configuration"
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Select a file to share"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                pendingFileURL = url
                showShareSheet = true
            }
        }
    }
}

struct MainContentView: View {
    @ObservedObject var configStore: ConfigStore
    let onShareFile: (URL) -> Void

    @State private var showShareSheet = false
    @State private var shareURL: URL?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Connected to S3")
                .font(.title)
                .fontWeight(.semibold)

            Text("Use the Share menu, right-click a file in Finder, or press \u{2318}\u{21E7}N to share via IShare.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                let panel = NSOpenPanel()
                panel.canChooseFiles = true
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = false
                panel.title = "Select a file to share"
                panel.begin { response in
                    if response == .OK, let url = panel.url {
                        shareURL = url
                        showShareSheet = true
                    }
                }
            } label: {
                Label("Share a File...", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(width: 400, height: 320)
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareSheetView(fileURL: url, configStore: configStore)
            }
        }
    }
}
