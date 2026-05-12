import SwiftUI

struct SettingsView: View {
    @ObservedObject var configStore: ConfigStore
    @State private var bucketName: String = ""
    @State private var region: String = "us-east-1"

    @State private var isTesting = false
    @State private var connectionStatus: ConfigView.ConnectionStatus = .idle
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text("S3 Bucket Configuration")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.vertical, 16)

            if let account = configStore.ds3Auth.currentAccount {
                HStack {
                    Image(systemName: "person.circle")
                        .foregroundStyle(.secondary)
                    Text("\(account.firstName) \(account.lastName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)
            }

            Form {
                Section {
                    TextField("Bucket Name", text: $bucketName)
                        .textFieldStyle(.roundedBorder)
                    TextField("Region", text: $region)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("S3 Bucket")
                }
            }
            .formStyle(.grouped)

            VStack(spacing: 4) {
                if connectionStatus == .testing {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Testing...")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } else if case .failed(let msg) = connectionStatus {
                    Text(msg)
                        .font(.callout)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else if connectionStatus == .connected {
                    Text("Connection successful")
                        .font(.callout)
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal)
            .frame(height: 40)

            if let error = errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            HStack(spacing: 12) {
                Button("Test Connection") {
                    Task { await testConnection() }
                }
                .disabled(isTesting || !formValid)

                Button("Save Changes") {
                    Task { await saveAndConnect() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isTesting || !formValid)

                Button("Disconnect") {
                    configStore.clear()
                    dismiss()
                }

                Button("Cancel") {
                    dismiss()
                }
            }
            .padding(.vertical, 16)
        }
        .frame(width: 480)
        .fixedSize()
        .onAppear {
            bucketName = configStore.config.bucketName
            region = configStore.config.region
        }
    }

    private var formValid: Bool {
        !bucketName.isEmpty
    }

    private func testConnection() async {
        isTesting = true
        connectionStatus = .testing
        errorMessage = nil

        guard let endpoint = configStore.ds3Auth.endpointGateway,
              let accessKey = configStore.ds3Auth.s3AccessKey,
              let secretKey = configStore.ds3Auth.s3SecretKey else {
            connectionStatus = .failed("DS3 authentication data unavailable")
            isTesting = false
            return
        }

        let config = S3Config(
            endpointURL: endpoint,
            accessKey: accessKey,
            secretKey: secretKey,
            bucketName: bucketName,
            region: region
        )

        let service = S3Service(config: config)
        let result = await service.testConnection()
        connectionStatus = switch result {
        case .success:
            .connected
        case .failure(let error):
            .failed(error.localizedDescription)
        }

        isTesting = false
    }

    private func saveAndConnect() async {
        isTesting = true
        connectionStatus = .testing
        errorMessage = nil

        guard let endpoint = configStore.ds3Auth.endpointGateway,
              let accessKey = configStore.ds3Auth.s3AccessKey,
              let secretKey = configStore.ds3Auth.s3SecretKey else {
            connectionStatus = .failed("DS3 authentication data unavailable")
            isTesting = false
            return
        }

        let config = S3Config(
            endpointURL: endpoint,
            accessKey: accessKey,
            secretKey: secretKey,
            bucketName: bucketName,
            region: region
        )

        let service = S3Service(config: config)

        let testResult = await service.testConnection()
        guard case .success = testResult else {
            if case .failure(let error) = testResult {
                connectionStatus = .failed(error.localizedDescription)
            }
            isTesting = false
            return
        }
        connectionStatus = .connected

        let bucketResult = await service.ensureBucketExists()
        if case .failure(let error) = bucketResult {
            errorMessage = "Bucket setup failed: \(error.localizedDescription)"
            isTesting = false
            return
        }

        configStore.config = config
        guard configStore.save() else {
            errorMessage = "Failed to save credentials"
            isTesting = false
            return
        }

        dismiss()
    }
}
