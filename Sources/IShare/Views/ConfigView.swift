import SwiftUI

enum LoginStep {
    case credentials
    case bucketConfig
}

struct ConfigView: View {
    @ObservedObject var configStore: ConfigStore

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var tfaCode: String = ""
    @State private var showTFA: Bool = false
    @State private var tenant: String = ""

    @State private var bucketName: String = ""
    @State private var region: String = "us-east-1"

    @State private var step: LoginStep = .credentials

    @State private var isProcessing = false
    @State private var connectionStatus: ConnectionStatus = .idle
    @State private var errorMessage: String?

    enum ConnectionStatus: Equatable {
        case idle
        case testing
        case loggedIn
        case connected
        case failed(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            switch step {
            case .credentials:
                credentialsView
            case .bucketConfig:
                bucketConfigView
            }
        }
        .frame(width: 480)
        .fixedSize()
    }

    // MARK: - Credentials View

    private var credentialsView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Image(systemName: "externaldrive.connected.to.line.below.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.tint)
                Text("Connect to Cubbit DS3")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Sign in with your Cubbit account")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 20)

            Form {
                Section {
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)

                    TextField("Tenant ID (optional)", text: $tenant)
                        .textFieldStyle(.roundedBorder)
                        .help("Leave empty for default tenant")

                    if showTFA {
                        TextField("2FA Code", text: $tfaCode)
                            .textFieldStyle(.roundedBorder)
                    }
                } header: {
                    Text("Cubbit Account")
                }
            }
            .formStyle(.grouped)
            .frame(minHeight: 200)

            statusSection

            Button {
                Task { await login() }
            } label: {
                Text("Sign In")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isProcessing || email.isEmpty || password.isEmpty)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Bucket Config View

    private var bucketConfigView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.green)
                Text("Signed in as \(email)")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Configure your S3 bucket")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 20)

            Form {
                Section {
                    TextField("Bucket Name", text: $bucketName)
                        .textFieldStyle(.roundedBorder)
                        .help("Bucket will be auto-created if it doesn't exist")

                    TextField("Region", text: $region)
                        .textFieldStyle(.roundedBorder)
                        .help("Default: us-east-1")
                } header: {
                    Text("S3 Bucket")
                }
            }
            .formStyle(.grouped)
            .frame(minHeight: 140)

            statusSection

            HStack(spacing: 12) {
                Button("Test Connection") {
                    Task { await testConnection() }
                }
                .disabled(isProcessing || !bucketNameValid)

                Button("Save & Connect") {
                    Task { await saveAndConnect() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing || !bucketNameValid)

                Button("Disconnect") {
                    configStore.clear()
                    resetToCredentials()
                }
            }
            .padding(.vertical, 16)
        }
    }

    // MARK: - Common

    private var statusSection: some View {
        VStack(spacing: 4) {
            if connectionStatus == .testing {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Working...")
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
                Text("Connected successfully")
                    .font(.callout)
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal)
        .frame(height: 40)
    }

    private var bucketNameValid: Bool {
        !bucketName.isEmpty
    }

    private func resetToCredentials() {
        step = .credentials
        connectionStatus = .idle
        errorMessage = nil
        password = ""
        tfaCode = ""
        showTFA = false
    }

    // MARK: - Login

    private func login() async {
        isProcessing = true
        connectionStatus = .testing
        errorMessage = nil

        do {
            try await configStore.ds3Auth.login(
                email: email,
                password: password,
                tfaCode: tfaCode.isEmpty ? nil : tfaCode,
                tenant: tenant.isEmpty ? nil : tenant
            )

            connectionStatus = .loggedIn
            step = .bucketConfig
            isProcessing = false
        } catch DS3AuthError.missing2FA {
            showTFA = true
            connectionStatus = .idle
            errorMessage = "Two-factor authentication code required"
            isProcessing = false
        } catch DS3AuthError.serverError(let code, let body) {
            connectionStatus = .failed("Server error (\(code)): \(body.prefix(200))")
            isProcessing = false
        } catch {
            connectionStatus = .failed(error.localizedDescription)
            isProcessing = false
        }
    }

    // MARK: - Test & Save

    private func testConnection() async {
        isProcessing = true
        connectionStatus = .testing
        errorMessage = nil

        guard let endpoint = configStore.ds3Auth.endpointGateway,
              let accessKey = configStore.ds3Auth.s3AccessKey,
              let secretKey = configStore.ds3Auth.s3SecretKey else {
            connectionStatus = .failed("DS3 authentication incomplete")
            isProcessing = false
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

        switch result {
        case .success:
            connectionStatus = .connected
        case .failure(let error):
            connectionStatus = .failed(error.localizedDescription)
        }

        isProcessing = false
    }

    private func saveAndConnect() async {
        isProcessing = true
        connectionStatus = .testing
        errorMessage = nil

        guard let endpoint = configStore.ds3Auth.endpointGateway,
              let accessKey = configStore.ds3Auth.s3AccessKey,
              let secretKey = configStore.ds3Auth.s3SecretKey else {
            connectionStatus = .failed("DS3 authentication incomplete")
            isProcessing = false
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
        switch testResult {
        case .success:
            connectionStatus = .connected
        case .failure(let error):
            connectionStatus = .failed(error.localizedDescription)
            isProcessing = false
            return
        }

        let bucketResult = await service.ensureBucketExists()
        switch bucketResult {
        case .success:
            break
        case .failure(let error):
            errorMessage = "Bucket setup failed: \(error.localizedDescription)"
            connectionStatus = .failed("Bucket error")
            isProcessing = false
            return
        }

        let lifecycleResult = await service.configureLifecycleRules()
        if case .failure(let error) = lifecycleResult {
            print("Warning: Lifecycle configuration failed: \(error.localizedDescription)")
        }

        configStore.config = config
        let saved = configStore.save()
        if !saved {
            errorMessage = "Failed to save credentials to Keychain"
            isProcessing = false
            return
        }

        isProcessing = false
    }
}
