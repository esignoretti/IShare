import SwiftUI

struct ConfigView: View {
    @StateObject private var configStore = ConfigStore()

    @State private var endpointURL: String = ""
    @State private var accessKey: String = ""
    @State private var secretKey: String = ""
    @State private var bucketName: String = ""
    @State private var region: String = "us-east-1"

    @State private var isTesting = false
    @State private var connectionStatus: ConnectionStatus = .idle
    @State private var errorMessage: String?

    enum ConnectionStatus: Equatable {
        case idle
        case testing
        case connected
        case failed(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Image(systemName: "externaldrive.connected.to.line.below.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.tint)
                Text("Connect to S3 Storage")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Enter your S3-compatible storage credentials")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 20)

            Form {
                Section {
                    TextField("Endpoint URL", text: $endpointURL)
                        .textFieldStyle(.roundedBorder)
                        .help("e.g. https://ds3.cubbit.eu")

                    TextField("Access Key", text: $accessKey)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Secret Key", text: $secretKey)
                        .textFieldStyle(.roundedBorder)

                    TextField("Bucket Name", text: $bucketName)
                        .textFieldStyle(.roundedBorder)
                        .help("Bucket will be auto-created if it doesn't exist")

                    TextField("Region", text: $region)
                        .textFieldStyle(.roundedBorder)
                        .help("Default: us-east-1")
                } header: {
                    Text("S3 Credentials")
                }
            }
            .formStyle(.grouped)
            .frame(minHeight: 280)

            ConnectionStatusView(status: connectionStatus)

            if let error = errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            HStack(spacing: 12) {
                Button("Test Connection") {
                    Task { await testConnection() }
                }
                .disabled(isTesting || !formValid)

                Button("Save & Connect") {
                    Task { await saveAndConnect() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isTesting || !formValid)
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

        switch result {
        case .success:
            connectionStatus = .connected
        case .failure(let error):
            connectionStatus = .failed(error.localizedDescription)
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
        switch testResult {
        case .success:
            connectionStatus = .connected
        case .failure(let error):
            connectionStatus = .failed(error.localizedDescription)
            isTesting = false
            return
        }

        let bucketResult = await service.ensureBucketExists()
        switch bucketResult {
        case .success:
            break
        case .failure(let error):
            errorMessage = "Bucket setup failed: \(error.localizedDescription)"
            connectionStatus = .failed("Bucket error")
            isTesting = false
            return
        }

        // Configure lifecycle rules (best-effort — non-blocking)
        let lifecycleResult = await service.configureLifecycleRules()
        if case .failure(let error) = lifecycleResult {
            print("Warning: Lifecycle configuration failed: \(error.localizedDescription)")
        }

        configStore.config = config
        let saved = configStore.save()
        if !saved {
            errorMessage = "Failed to save credentials to Keychain"
            isTesting = false
            return
        }

        isTesting = false
    }
}
