import SwiftUI
import AppKit

struct ShareSheetView: View {
    let fileURL: URL
    @ObservedObject var configStore: ConfigStore
    @EnvironmentObject var historyStore: ShareHistoryStore
    let autoStart: Bool
    let onClose: (() -> Void)?

    @State private var shareItem: ShareItem
    @State private var isSharing = false
    @State private var showSuccess = false
    @State private var showRecipientFields = false
    @State private var encryptionPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var showEncryptionDisclosure = false
    @State private var passwordMismatch = false

    init(fileURL: URL, configStore: ConfigStore, autoStart: Bool = false, onClose: (() -> Void)? = nil) {
        self.fileURL = fileURL
        self.configStore = configStore
        self.autoStart = autoStart
        self.onClose = onClose
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
                ScrollView {
                    shareOptionsView
                }
            }
        }
        .frame(width: 400, height: 480)
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
                .labelsHidden()
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

            DisclosureGroup("Notify Recipient (Optional)", isExpanded: $showRecipientFields) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Recipient Name", text: $shareItem.recipientInfo.recipientName)
                        .textFieldStyle(.roundedBorder)
                    TextField("Recipient Email", text: $shareItem.recipientInfo.recipientEmail)
                        .textFieldStyle(.roundedBorder)
                    TextField("Personal Message (optional)", text: $shareItem.recipientInfo.personalMessage, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)

            DisclosureGroup("Encrypt with Password (Optional)", isExpanded: $showEncryptionDisclosure) {
                VStack(alignment: .leading, spacing: 8) {
                    SecureField("Password", text: $encryptionPassword)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Confirm Password", text: $confirmPassword)
                        .textFieldStyle(.roundedBorder)

                    if passwordMismatch {
                        Text("Passwords do not match")
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    Text("File will be encrypted with AES-256-CBC before upload. Share the password separately — it will NOT be included in the email.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)

            Divider()
                .padding(.vertical, 8)

            HStack(spacing: 12) {
                Button("Cancel") {
                    onClose?()
                }
                .keyboardShortcut(.escape)

                Button("Share") {
                    if showEncryptionDisclosure && !encryptionPassword.isEmpty {
                        guard encryptionPassword == confirmPassword else {
                            passwordMismatch = true
                            return
                        }
                        passwordMismatch = false
                        shareItem.encryptionPassword = encryptionPassword
                    }
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
                    onClose?()
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
        case .encrypting: return "lock.shield"
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
        case .encrypting: return "Encrypting..."
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

                    if shareItem.hasRecipient {
                        Button {
                            composeEmail(for: shareItem)
                        } label: {
                            Image(systemName: "envelope")
                        }
                        .buttonStyle(.borderless)
                        .help("Open email draft")
                    }
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
                onClose?()
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
        let shareService = ShareService(s3Service: s3Service, shareHistoryStore: historyStore)

        let result = await shareService.share(shareItem) { updatedItem in
            Task { @MainActor in
                self.shareItem = updatedItem
                if updatedItem.state == .complete {
                    withAnimation {
                        self.showSuccess = true
                        self.copyToClipboard(updatedItem.presignedURL ?? "")
                    }
                    if updatedItem.hasRecipient {
                        composeEmail(for: updatedItem)
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

    private func composeEmail(for item: ShareItem) {
        guard item.hasRecipient else { return }

        let subject = "\(item.displayName) shared with you via IShare"
        let expiryText: String
        if item.duration == .forever {
            expiryText = "This link never expires."
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            let expiryDate = Date().addingTimeInterval(TimeInterval(item.duration.seconds))
            expiryText = "This link expires on \(formatter.string(from: expiryDate))."
        }

        var body = "Hello"
        if !item.recipientInfo.recipientName.isEmpty {
            body += " \(item.recipientInfo.recipientName)"
        }
        body += ",\n\n\(item.displayName) has been shared with you.\n\n"
        body += "Download link: \(item.presignedURL ?? "N/A")\n\n"
        body += expiryText + "\n"
        if !item.recipientInfo.personalMessage.isEmpty {
            body += "\nMessage from sender:\n\(item.recipientInfo.personalMessage)\n"
        }

        if item.isEncrypted {
            body += "\n\nThis file is password-protected. The sender will provide the password separately."
        }

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = item.recipientInfo.recipientEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]

        guard let url = components.url else { return }
        NSWorkspace.shared.open(url)
    }
}
