import SwiftUI

enum LoginStep {
    case credentials
    case selectProject
    case bucketConfig
}

struct ConfigView: View {
    @ObservedObject var configStore: ConfigStore

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var tfaCode: String = ""
    @State private var showTFA: Bool = false
    @State private var tenant: String = ""
    @State private var coordinatorURL: String = CubbitAPIURLs.defaultCoordinatorURL
    @State private var showAdvanced = false

    @State private var projects: [Project] = []
    @State private var selectedProject: Project?
    @State private var bucketName: String = ""

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
            case .selectProject:
                selectProjectView
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

                    DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
                        VStack(spacing: 8) {
                            TextField("Coordinator URL", text: $coordinatorURL)
                                .textFieldStyle(.roundedBorder)
                                .help("Default: https://api.eu00wi.cubbit.services")

                            TextField("Tenant ID (optional)", text: $tenant)
                                .textFieldStyle(.roundedBorder)
                                .help("Leave empty for default tenant")
                        }
                        .padding(.top, 4)
                    }

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

    // MARK: - Project Selection View

    private var selectProjectView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Image(systemName: "folder")
                    .font(.system(size: 32))
                    .foregroundStyle(.tint)
                Text("Select Project")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Choose a project to use for sharing files")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 20)

            if projects.isEmpty {
                Text("No projects found")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                List(projects, id: \.id) { project in
                    Button {
                        selectedProject = project
                        bucketName = project.name.lowercased().replacingOccurrences(of: " ", with: "-")
                        step = .bucketConfig
                    } label: {
                        HStack {
                            Image(systemName: selectedProject?.id == project.id ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading) {
                                Text(project.name)
                                    .fontWeight(.medium)
                                Text("\(project.users.count) user(s)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .frame(height: 200)
                .padding(.horizontal, 20)
            }

            Button("Disconnect") {
                configStore.clear()
                resetToCredentials()
            }
            .padding(.vertical, 16)
        }
    }

    // MARK: - Bucket Config View

    private var bucketConfigView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.green)
                Text("Configure Bucket")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Bucket name was auto-filled from your project")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 20)

            Form {
                Section {
                    TextField("Bucket Name", text: $bucketName)
                        .textFieldStyle(.roundedBorder)
                        .help("Bucket will be auto-created if it doesn't exist")
                } header: {
                    Text("S3 Bucket")
                }
            }
            .formStyle(.grouped)
            .frame(minHeight: 100)

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

                Button("Back") {
                    step = .selectProject
                }

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
                tenant: tenant.isEmpty ? nil : tenant,
                coordinatorURL: coordinatorURL.isEmpty ? nil : coordinatorURL
            )

            let fetched = try await configStore.ds3Auth.fetchProjects()
            projects = fetched

            connectionStatus = .loggedIn
            if projects.count == 1, let project = projects.first {
                selectedProject = project
                bucketName = project.name.lowercased().replacingOccurrences(of: " ", with: "-")
                step = .bucketConfig
            } else {
                step = .selectProject
            }
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

        guard let endpoint = configStore.ds3Auth.endpointGateway else {
            connectionStatus = .failed("DS3 authentication incomplete")
            isProcessing = false
            return
        }

        guard let project = selectedProject,
              let user = project.users.first(where: { $0.isRoot }) ?? project.users.first else {
            connectionStatus = .failed("No IAM user for selected project")
            isProcessing = false
            return
        }

        do {
            try await configStore.ds3Auth.provisionApiKey(for: user, projectName: project.name)
        } catch {
            connectionStatus = .failed("API key provisioning failed: \(error.localizedDescription)")
            isProcessing = false
            return
        }

        guard let accessKey = configStore.ds3Auth.s3AccessKey,
              let secretKey = configStore.ds3Auth.s3SecretKey else {
            connectionStatus = .failed("API key missing secret")
            isProcessing = false
            return
        }

        let config = S3Config(
            endpointURL: endpoint,
            accessKey: accessKey,
            secretKey: secretKey,
            bucketName: bucketName,
            region: "us-east-1"
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

        guard let endpoint = configStore.ds3Auth.endpointGateway else {
            connectionStatus = .failed("DS3 authentication incomplete")
            isProcessing = false
            return
        }

        guard let project = selectedProject,
              let user = project.users.first(where: { $0.isRoot }) ?? project.users.first else {
            connectionStatus = .failed("No IAM user for selected project")
            isProcessing = false
            return
        }

        do {
            try await configStore.ds3Auth.provisionApiKey(for: user, projectName: project.name)
        } catch {
            connectionStatus = .failed("API key provisioning failed: \(error.localizedDescription)")
            isProcessing = false
            return
        }

        guard let accessKey = configStore.ds3Auth.s3AccessKey,
              let secretKey = configStore.ds3Auth.s3SecretKey else {
            connectionStatus = .failed("API key missing secret")
            isProcessing = false
            return
        }

        let config = S3Config(
            endpointURL: endpoint,
            accessKey: accessKey,
            secretKey: secretKey,
            bucketName: bucketName,
            region: "us-east-1"
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
