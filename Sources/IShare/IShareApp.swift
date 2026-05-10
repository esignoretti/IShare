import SwiftUI

extension Notification.Name {
    static let shareFileReceived = Notification.Name("com.isare.shareFileReceived")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        guard let firstPath = filenames.first else { return }

        let url = URL(fileURLWithPath: firstPath)

        guard FileManager.default.fileExists(atPath: url.path) else { return }

        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .shareFileReceived,
                object: nil,
                userInfo: ["fileURL": url]
            )
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

@main
struct IShareApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var configStore = ConfigStore()
    @StateObject private var historyStore = ShareHistoryStore()
    @State private var showShareSheet = false
    @State private var pendingFileURL: URL?
    @State private var autoStartShare = false

    var body: some Scene {
        WindowGroup {
            if configStore.isConfigured {
                MainContentView(
                    configStore: configStore,
                    onShareFile: { url in
                        pendingFileURL = url
                        autoStartShare = false
                        showShareSheet = true
                    }
                )
                .environmentObject(configStore)
                .environmentObject(historyStore)
                .sheet(isPresented: $showShareSheet) {
                    if let url = pendingFileURL {
                        ShareSheetView(fileURL: url, configStore: configStore, autoStart: autoStartShare)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .shareFileReceived)) { notification in
                    if let url = notification.userInfo?["fileURL"] as? URL {
                        pendingFileURL = url
                        autoStartShare = true
                        showShareSheet = true
                    }
                }
            } else {
                ConfigView()
                    .environmentObject(historyStore)
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

        MenuBarExtra {
            let s3Service = S3Service(config: configStore.config)
            MenuBarTrayView(
                historyStore: historyStore,
                s3Service: s3Service,
                onBadgeUpdate: { _ in }
            )
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .menuBarExtraStyle(.window)
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
                autoStartShare = false
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
