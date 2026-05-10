import SwiftUI

struct SettingsView: View {
    @ObservedObject var configStore: ConfigStore
    @State private var endpointURL: String = ""
    @State private var accessKey: String = ""
    @State private var secretKey: String = ""
    @State private var bucketName: String = ""
    @State private var region: String = "us-east-1"

    @State private var isTesting = false
    @State private var connectionStatus: ConfigView.ConnectionStatus = .idle
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text("S3 Configuration")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.vertical, 16)

            Form {
                Section {
                    TextField("Endpoint URL", text: $endpointURL)
                        .textFieldStyle(.roundedBorder)
                    TextField("Access Key", text: $accessKey)
                        .textFieldStyle(.roundedBorder)
                    SecureField("Secret Key", text: $secretKey)
                        .textFieldStyle(.roundedBorder)
                    TextField("Bucket Name", text: $bucketName)
                        .textFieldStyle(.roundedBorder)
                    TextField("Region", text: $region)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("S3 Credentials")
                }
            }
            .formStyle(.grouped)

            ConnectionStatusView(status: connectionStatus)
                .padding(.bottom, 8)

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

                Button("Cancel") {
                    dismiss()
                }
            }
            .padding(.vertical, 16)
        }
        .frame(width: 480)
        .fixedSize()
        .onAppear {
            endpointURL = configStore.config.endpointURL
            accessKey = configStore.config.accessKey
            secretKey = configStore.config.secretKey
            bucketName = configStore.config.bucketName
            region = configStore.config.region
        }
    }

    private var formValid: Bool {
        !endpointURL.isEmpty && !accessKey.isEmpty
            && !secretKey.isEmpty && !bucketName.isEmpty
    }

    private func testConnection() async {
        isTesting = true
        connectionStatus = .testing
        errorMessage = nil

        let config = S3Config(
            endpointURL: endpointURL,
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

        let config = S3Config(
            endpointURL: endpointURL,
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
