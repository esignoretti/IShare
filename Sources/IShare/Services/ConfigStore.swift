import Foundation
import Combine

@MainActor
class ConfigStore: ObservableObject {
    @Published var config: S3Config {
        didSet {
            saveNonSecrets()
        }
    }

    @Published var isConfigured: Bool = false

    private let keychain = KeychainManager()
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let endpointURL = "s3_endpoint_url"
        static let bucketName = "s3_bucket_name"
        static let region = "s3_region"
        static let isConfigured = "s3_is_configured"
    }

    init() {
        let endpoint = defaults.string(forKey: Keys.endpointURL) ?? ""
        let bucket = defaults.string(forKey: Keys.bucketName) ?? ""
        let region = defaults.string(forKey: Keys.region) ?? "us-east-1"
        let configured = defaults.bool(forKey: Keys.isConfigured)

        let accessKey: String
        let secretKey: String
        if configured {
            accessKey = (try? keychain.readAccessKey()) ?? ""
            secretKey = (try? keychain.readSecretKey()) ?? ""
        } else {
            accessKey = ""
            secretKey = ""
        }

        self.config = S3Config(
            endpointURL: endpoint,
            accessKey: accessKey,
            secretKey: secretKey,
            bucketName: bucket,
            region: region
        )
        self.isConfigured = configured && self.config.isValid
    }

    func save() -> Bool {
        do {
            try keychain.saveAccessKey(config.accessKey)
            try keychain.saveSecretKey(config.secretKey)
            saveNonSecrets()
            isConfigured = config.isValid
            defaults.set(isConfigured, forKey: Keys.isConfigured)
            return true
        } catch {
            return false
        }
    }

    func clear() {
        try? keychain.deleteAll()
        defaults.removeObject(forKey: Keys.endpointURL)
        defaults.removeObject(forKey: Keys.bucketName)
        defaults.removeObject(forKey: Keys.region)
        defaults.removeObject(forKey: Keys.isConfigured)
        config = S3Config()
        isConfigured = false
    }

    private func saveNonSecrets() {
        defaults.set(config.endpointURL, forKey: Keys.endpointURL)
        defaults.set(config.bucketName, forKey: Keys.bucketName)
        defaults.set(config.region, forKey: Keys.region)
    }
}
