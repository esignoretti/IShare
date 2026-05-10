import SwiftUI

@main
struct IShareApp: App {
    @StateObject private var configStore = ConfigStore()

    var body: some Scene {
        WindowGroup {
            if configStore.isConfigured {
                MainContentView()
                    .environmentObject(configStore)
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
}

struct MainContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Connected to S3")
                .font(.title)
                .fontWeight(.semibold)

            Text("You're all set. Use Quick Actions or right-click a file in Finder to share via IShare.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(width: 400, height: 300)
    }
}
