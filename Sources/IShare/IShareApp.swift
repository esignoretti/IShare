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
    @State private var shareWindowController: NSWindowController?

    func presentShareWindow(for url: URL, autoStart: Bool) {
        let shareView = ShareSheetView(
            fileURL: url,
            configStore: configStore,
            autoStart: autoStart,
            onClose: {
                NSApplication.shared.keyWindow?.close()
            }
        )
            .environmentObject(historyStore)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 440),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Share File"
        window.contentView = NSHostingView(rootView: shareView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        shareWindowController = NSWindowController(window: window)
    }

    var body: some Scene {
        WindowGroup {
            if configStore.isConfigured {
                MainContentView(
                    configStore: configStore,
                    onShareFile: { url in
                        presentShareWindow(for: url, autoStart: false)
                    }
                )
                .environmentObject(configStore)
                .environmentObject(historyStore)
                .onReceive(NotificationCenter.default.publisher(for: .shareFileReceived)) { notification in
                    if let url = notification.userInfo?["fileURL"] as? URL {
                        presentShareWindow(for: url, autoStart: true)
                    }
                }
            } else {
                ConfigView(configStore: configStore)
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
        // Bring the app window to front before showing the panel
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Select a file or folder to share"
        panel.prompt = "Share"
        panel.message = "Choose a file or folder to share via IShare"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                presentShareWindow(for: url, autoStart: false)
            }
        }
    }
}

struct MainContentView: View {
    @ObservedObject var configStore: ConfigStore
    let onShareFile: (URL) -> Void

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
                        onShareFile(url)
                    }
                }
            } label: {
                Label("Share a File...", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(width: 400, height: 320)
    }
}
