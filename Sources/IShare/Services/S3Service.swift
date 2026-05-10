import Foundation

enum S3Error: Error, LocalizedError {
    case invalidConfig(String)
    case connectionFailed(String)
    case bucketCheckFailed(String)
    case bucketCreationFailed(String)
    case unexpected(Error)

    var errorDescription: String? {
        switch self {
        case .invalidConfig(let msg): return "Invalid configuration: \(msg)"
        case .connectionFailed(let msg): return "Connection failed: \(msg)"
        case .bucketCheckFailed(let msg): return "Bucket check failed: \(msg)"
        case .bucketCreationFailed(let msg): return "Bucket creation failed: \(msg)"
        case .unexpected(let err): return "Unexpected error: \(err.localizedDescription)"
        }
    }
}

struct S3Service {
    private let config: S3Config

    init(config: S3Config) {
        self.config = config
    }

    private var baseURL: URL? {
        guard var components = URLComponents(string: config.endpointURL) else { return nil }
        if components.path.isEmpty {
            components.path = ""
        }
        return components.url
    }

    private func makeRequest(path: String, method: String, body: Data? = nil) -> URLRequest? {
        guard let base = baseURL else { return nil }
        let url = base.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(config.bucketName, forHTTPHeaderField: "x-amz-bucket")

        let dateString = ISO8601DateFormatter().string(from: Date())
        request.setValue(dateString, forHTTPHeaderField: "Date")

        if let body = body {
            request.httpBody = body
            request.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")
        }

        return request
    }

    func testConnection() async -> Result<[String], S3Error> {
        guard config.isValid else {
            return .failure(.invalidConfig("All credential fields must be non-empty"))
        }

        // List all buckets via GET /
        guard let base = baseURL else {
            return .failure(.connectionFailed("Invalid endpoint URL"))
        }

        var request = URLRequest(url: base)
        request.httpMethod = "GET"
        request.setValue(config.accessKey, forHTTPHeaderField: "x-amz-access-key")
        request.setValue(ISO8601DateFormatter().string(from: Date()), forHTTPHeaderField: "Date")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.connectionFailed("Invalid response"))
            }

            if httpResponse.statusCode == 200 {
                // Parse bucket names from response XML
                let xml = String(data: data, encoding: .utf8) ?? ""
                let bucketNames = parseBucketNames(from: xml)
                return .success(bucketNames)
            } else {
                return .failure(.connectionFailed("HTTP \(httpResponse.statusCode)"))
            }
        } catch {
            return .failure(.connectionFailed(error.localizedDescription))
        }
    }

    func ping() async -> Bool {
        let result = await testConnection()
        switch result {
        case .success: return true
        case .failure(let err):
            switch err {
            case .connectionFailed, .invalidConfig: return false
            default: return true
            }
        }
    }

    func bucketExists() async -> Result<Bool, S3Error> {
        guard config.isValid else {
            return .failure(.invalidConfig("All credential fields must be non-empty"))
        }

        guard let base = baseURL else {
            return .failure(.connectionFailed("Invalid endpoint URL"))
        }

        let url = base.appendingPathComponent(config.bucketName)
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.setValue(config.accessKey, forHTTPHeaderField: "x-amz-access-key")
        request.setValue(ISO8601DateFormatter().string(from: Date()), forHTTPHeaderField: "Date")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.bucketCheckFailed("Invalid response"))
            }

            switch httpResponse.statusCode {
            case 200: return .success(true)
            case 404: return .success(false)
            default: return .failure(.bucketCheckFailed("HTTP \(httpResponse.statusCode)"))
            }
        } catch {
            return .failure(.bucketCheckFailed(error.localizedDescription))
        }
    }

    func createBucket() async -> Result<Void, S3Error> {
        guard config.isValid else {
            return .failure(.invalidConfig("All credential fields must be non-empty"))
        }

        guard let base = baseURL else {
            return .failure(.connectionFailed("Invalid endpoint URL"))
        }

        let url = base.appendingPathComponent(config.bucketName)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(config.accessKey, forHTTPHeaderField: "x-amz-access-key")
        request.setValue(ISO8601DateFormatter().string(from: Date()), forHTTPHeaderField: "Date")

        if config.region != "us-east-1" {
            let locationConstraintXML = """
            <CreateBucketConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
                <LocationConstraint>\(config.region)</LocationConstraint>
            </CreateBucketConfiguration>
            """
            request.httpBody = locationConstraintXML.data(using: .utf8)
            request.setValue("application/xml", forHTTPHeaderField: "Content-Type")
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.bucketCreationFailed("Invalid response"))
            }

            if httpResponse.statusCode == 200 {
                return .success(())
            } else {
                return .failure(.bucketCreationFailed("HTTP \(httpResponse.statusCode)"))
            }
        } catch {
            return .failure(.bucketCreationFailed(error.localizedDescription))
        }
    }

    func ensureBucketExists() async -> Result<Bool, S3Error> {
        let exists = await bucketExists()
        switch exists {
        case .success(true):
            return .success(true)
        case .success(false):
            let created = await createBucket()
            switch created {
            case .success:
                return .success(false)
            case .failure(let error):
                return .failure(error)
            }
        case .failure(let error):
            return .failure(error)
        }
    }

    // MARK: - XML Parsing

    private func parseBucketNames(from xml: String) -> [String] {
        var names: [String] = []
        var searchRange = xml.startIndex..<xml.endIndex

        while true {
            guard let openTag = xml[searchRange].range(of: "<Name>"),
                  let closeTag = xml[searchRange].range(of: "</Name>"),
                  openTag.lowerBound < closeTag.upperBound else {
                break
            }

            let nameStart = openTag.upperBound
            let nameEnd = closeTag.lowerBound
            let name = String(xml[nameStart..<nameEnd])
            names.append(name)

            searchRange = closeTag.upperBound..<xml.endIndex
        }

        return names
    }
}
