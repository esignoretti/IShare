import SwiftUI

struct ConnectionStatusView: View {
    let status: ConfigView.ConnectionStatus

    var body: some View {
        HStack(spacing: 8) {
            switch status {
            case .idle:
                Image(systemName: "circle.dashed")
                    .foregroundStyle(.secondary)
                Text("Not connected")
                    .foregroundStyle(.secondary)

            case .testing:
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 16, height: 16)
                Text("Testing connection...")
                    .foregroundStyle(.secondary)

            case .connected:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Connected")
                    .foregroundStyle(.primary)

            case .failed(let reason):
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text("Connection failed")
                    .foregroundStyle(.red)
                if !reason.isEmpty {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .font(.subheadline)
        .padding(.vertical, 4)
    }
}
