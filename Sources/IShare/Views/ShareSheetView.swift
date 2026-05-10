import SwiftUI

struct ShareSheetView: View {
    let fileURL: URL
    @ObservedObject var configStore: ConfigStore
    let autoStart: Bool

    @State private var shareItem: ShareItem
    @State private var isSharing = false
    @State private var showSuccess = false

    @Environment(\.dismiss) private var dismiss

    init(fileURL: URL, configStore: ConfigStore, autoStart: Bool = false) {
        self.fileURL = fileURL
        self.configStore = configStore
        self.autoStart = autoStart
        let isDir = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        self._shareItem = State(initialValue: ShareItem(
            fileURL: fileURL,
            compress: isDir ? true : false
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 32))
                    .foregroundStyle(.tint)

                Text("Share File")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(shareItem.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.vertical, 16)

            if showSuccess {
                successView
            } else if isSharing {
                progressView
            } else {
                shareOptionsView
            }
        }
        .frame(width: 400)
        .fixedSize()
        .onAppear {
            if autoStart && !isSharing && !showSuccess {
                Task { await startShare() }
            }
        }
    }

    private var shareOptionsView: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Expires in")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("Duration", selection: $shareItem.duration) {
                    ForEach(ShareDuration.allCases) { duration in
                        Text(duration.label).tag(duration)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 20)

            if !shareItem.isDirectory {
                Toggle(isOn: $shareItem.compress) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Compress as ZIP")
                            .font(.subheadline)
                        Text("Reduces file size for faster upload")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
            } else {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text("Directories are always compressed to ZIP")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
            }

            Divider()
                .padding(.vertical, 8)

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button("Share") {
                    Task { await startShare() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.bottom, 16)
        }
    }

    private var progressView: some View {
        VStack(spacing: 16) {
            ProgressView(value: shareItem.progress) {
                HStack {
                    Image(systemName: statusIcon)
                        .foregroundStyle(.secondary)
                    Text(statusText)
                        .font(.subheadline)
                }
            }
            .progressViewStyle(.linear)
            .padding(.horizontal, 40)

            if case .failed(let error) = shareItem.state {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                Button("Close") {
                    dismiss()
                }
                .padding(.bottom, 16)
            }
        }
        .padding(.vertical, 32)
    }

    private var statusIcon: String {
        switch shareItem.state {
        case .pending: return "clock"
        case .compressing: return "archivebox"
        case .uploading: return "arrow.up.circle"
        case .generatingURL: return "link"
        case .complete: return "checkmark.circle"
        case .failed: return "exclamationmark.circle"
        }
    }

    private var statusText: String {
        switch shareItem.state {
        case .pending: return "Preparing..."
        case .compressing: return "Compressing..."
        case .uploading: return "Uploading... \(Int(shareItem.progress * 100))%"
        case .generatingURL: return "Generating link..."
        case .complete: return "Complete!"
        case .failed(let error): return "Failed: \(error)"
        }
    }

    private var successView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Shared Successfully!")
                .font(.title3)
                .fontWeight(.semibold)

            if let url = shareItem.presignedURL {
                HStack {
                    Text(url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)

                    Button {
                        copyToClipboard(url)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .help("Copy link to clipboard")
                }
                .padding(.horizontal, 20)
            }

            HStack(spacing: 4) {
                Text("Expires:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(shareItem.duration.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom, 8)
        }
        .padding(.vertical, 24)
    }

    @MainActor
    private func startShare() async {
        isSharing = true

        let s3Service = S3Service(config: configStore.config)
        let shareService = ShareService(s3Service: s3Service)

        let result = await shareService.share(shareItem) { updatedItem in
            Task { @MainActor in
                self.shareItem = updatedItem
                if updatedItem.state == .complete {
                    withAnimation {
                        self.showSuccess = true
                        self.copyToClipboard(updatedItem.presignedURL ?? "")
                    }
                }
            }
        }

        self.shareItem = result
        ShareService.cleanupTempFiles(for: result)
    }

    private func copyToClipboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}
