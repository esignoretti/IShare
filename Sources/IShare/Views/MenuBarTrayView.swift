import SwiftUI
import AppKit

struct MenuBarTrayView: View {
    @ObservedObject var historyStore: ShareHistoryStore
    let s3Service: S3Service
    let onBadgeUpdate: (Int) -> Void

    @State private var deletingIDs: Set<UUID> = []
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        VStack(spacing: 0) {
            if historyStore.records.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No shared files yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Share a file from the menu bar or Finder")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(historyStore.records.enumerated()), id: \.element.id) { index, record in
                            TrayEntryRow(
                                record: record,
                                isDeleting: deletingIDs.contains(record.id),
                                onCopy: { copyAndRegenerateLink(record) },
                                onDelete: { Task { await deleteRecord(record, at: index) } }
                            )
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)

                            if index < historyStore.records.count - 1 {
                                Divider()
                                    .padding(.leading, 8)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: min(CGFloat(historyStore.records.count) * 72, 360))
            }
        }
        .frame(width: 320)
        .alert("Error", isPresented: $showError, presenting: errorMessage) { message in
            Button("OK") {}
        } message: { message in
            Text(message)
        }
        .onAppear { onBadgeUpdate(historyStore.records.count) }
        .onChange(of: historyStore.records.count) { _, newCount in
            onBadgeUpdate(newCount)
        }
    }

    private func copyAndRegenerateLink(_ record: SharedFileRecord) {
        if let cached = record.presignedURL {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(cached, forType: .string)
        } else {
            let result = s3Service.generatePresignedURL(
                objectKey: record.objectKey,
                durationSeconds: record.duration.seconds == 0 ? 315_360_000 : record.duration.seconds
            )
            switch result {
            case .success(let url):
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url, forType: .string)
            case .failure(let error):
                errorMessage = "Failed to generate link: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    private func deleteRecord(_ record: SharedFileRecord, at index: Int) async {
        deletingIDs.insert(record.id)
        let result = await s3Service.deleteFile(objectKey: record.objectKey)
        switch result {
        case .success:
            historyStore.remove(at: index)
        case .failure(let error):
            historyStore.remove(at: index)
            errorMessage = "Deleted from tray but S3 removal failed: \(error.localizedDescription)"
            showError = true
        }
        deletingIDs.remove(record.id)
    }
}

struct TrayEntryRow: View {
    let record: SharedFileRecord
    let isDeleting: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: record.isEncrypted ? "lock.doc" : "doc")
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.fileName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 4) {
                    Label(record.duration.label, systemImage: "clock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if !record.isExpired && record.duration.seconds > 0 {
                        Text("\u{00B7}")
                            .foregroundStyle(.tertiary)
                        Text(record.remainingTimeLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if record.isExpired {
                        Text("\u{00B7} Expired")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 2) {
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Copy link")

                Button(action: onDelete) {
                    if isDeleting {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                }
                .buttonStyle(.borderless)
                .help("Delete share")
                .disabled(isDeleting)
            }
        }
        .padding(.horizontal, 4)
    }
}
