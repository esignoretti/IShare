import Foundation

struct S3Config: Codable, Equatable {
    var endpointURL: String
    var accessKey: String
    var secretKey: String
    var bucketName: String
    var region: String

    var isValid: Bool {
        !endpointURL.isEmpty
            && !accessKey.isEmpty
            && !secretKey.isEmpty
            && !bucketName.isEmpty
            && !region.isEmpty
    }

    var sanitized: S3Config {
        S3Config(
            endpointURL: endpointURL,
            accessKey: String(repeating: "•", count: max(accessKey.count, 8)),
            secretKey: String(repeating: "•", count: max(secretKey.count, 8)),
            bucketName: bucketName,
            region: region
        )
    }

    init(
        endpointURL: String = "",
        accessKey: String = "",
        secretKey: String = "",
        bucketName: String = "",
        region: String = "us-east-1"
    ) {
        self.endpointURL = endpointURL
        self.accessKey = accessKey
        self.secretKey = secretKey
        self.bucketName = bucketName
        self.region = region
    }
}
