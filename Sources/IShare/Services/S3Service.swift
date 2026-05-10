import Foundation

enum S3Error: Error, LocalizedError {
    case invalidConfig(String)
    case connectionFailed(String)
    case bucketCheckFailed(String)
    case bucketCreationFailed(String)
    case uploadFailed(String)
    case presignFailed(String)
    case signingFailed(String)
    case lifecycleConfigurationFailed(String)
    case deleteFailed(String)
    case unexpected(Error)

    var errorDescription: String? {
        switch self {
        case .invalidConfig(let msg): return "Invalid configuration: \(msg)"
        case .connectionFailed(let msg): return "Connection failed: \(msg)"
        case .bucketCheckFailed(let msg): return "Bucket check failed: \(msg)"
        case .bucketCreationFailed(let msg): return "Bucket creation failed: \(msg)"
        case .uploadFailed(let msg): return "Upload failed: \(msg)"
        case .presignFailed(let msg): return "Pre-signed URL generation failed: \(msg)"
        case .signingFailed(let msg): return "Signing failed: \(msg)"
        case .lifecycleConfigurationFailed(let msg): return "Lifecycle configuration failed: \(msg)"
        case .deleteFailed(let msg): return "Delete failed: \(msg)"
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

    // MARK: - File Upload / Delete

    func uploadFile(
        fileURL: URL,
        duration: String,
        progressHandler: ((Double) -> Void)? = nil
    ) async -> Result<String, S3Error> {
        guard config.isValid else {
            return .failure(.invalidConfig("All credential fields must be non-empty"))
        }

        guard let base = baseURL else {
            return .failure(.connectionFailed("Invalid endpoint URL"))
        }

        let filename = fileURL.lastPathComponent
        let objectKey = "shares/\(duration)/\(filename)"
        let url = base.appendingPathComponent(config.bucketName).appendingPathComponent(objectKey)

        guard let fileData = try? Data(contentsOf: fileURL) else {
            return .failure(.uploadFailed("Cannot read file at \(fileURL.path)"))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = fileData
        request.setValue(config.accessKey, forHTTPHeaderField: "x-amz-access-key")
        request.setValue(ISO8601DateFormatter().string(from: Date()), forHTTPHeaderField: "Date")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue("\(fileData.count)", forHTTPHeaderField: "Content-Length")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.uploadFailed("Invalid response"))
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                return .failure(.uploadFailed("HTTP \(httpResponse.statusCode)"))
            }

            progressHandler?(1.0)
            return .success(objectKey)
        } catch {
            return .failure(.uploadFailed(error.localizedDescription))
        }
    }

    // MARK: - Pre-signed URL Generation (SigV4)

    func generatePresignedURL(objectKey: String, durationSeconds: Int) -> Result<String, S3Error> {
        guard config.isValid else {
            return .failure(.invalidConfig("All credential fields must be non-empty"))
        }

        guard let base = baseURL,
              var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            return .failure(.presignFailed("Invalid endpoint URL"))
        }

        components.path = "/\(config.bucketName)/\(objectKey)"

        let now = Date()
        let amzDate = sigV4AmzDate(from: now)
        let dateStamp = sigV4DateStamp(from: now)
        let region = config.region
        let service = "s3"
        let algorithm = "AWS4-HMAC-SHA256"

        guard let host = components.host else {
            return .failure(.presignFailed("Cannot extract host from endpoint URL"))
        }

        let credentialScope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        let credential = "\(config.accessKey)/\(credentialScope)"

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "X-Amz-Algorithm", value: algorithm),
            URLQueryItem(name: "X-Amz-Credential", value: credential),
            URLQueryItem(name: "X-Amz-Date", value: amzDate),
            URLQueryItem(name: "X-Amz-Expires", value: "\(durationSeconds)"),
            URLQueryItem(name: "X-Amz-SignedHeaders", value: "host"),
        ]

        queryItems.sort { $0.name < $1.name || ($0.name == $1.name && ($0.value ?? "") < ($1.value ?? "")) }

        let canonicalQueryString = queryItems
            .compactMap { item -> String? in
                guard let value = item.value else { return nil }
                return "\(item.name.uriEncoded)=\(value.uriEncoded)"
            }
            .joined(separator: "&")

        let canonicalURI = components.path
        let canonicalHeaders = "host:\(host)\n"
        let signedHeaders = "host"
        let payloadHash = "UNSIGNED-PAYLOAD"

        let canonicalRequest = [
            "GET",
            canonicalURI,
            canonicalQueryString,
            canonicalHeaders,
            signedHeaders,
            payloadHash
        ].joined(separator: "\n")

        let stringToSign = [
            algorithm,
            amzDate,
            credentialScope,
            canonicalRequest.sha256Hex
        ].joined(separator: "\n")

        let signingKey = sigV4SigningKey(
            secretKey: config.secretKey,
            dateStamp: dateStamp,
            region: region,
            service: service
        )
        let signature = stringToSign.hmacSHA256(key: signingKey).hexString

        var finalQueryItems = queryItems
        finalQueryItems.append(URLQueryItem(name: "X-Amz-Signature", value: signature))
        components.percentEncodedQuery = finalQueryItems
            .compactMap { item -> String? in
                guard let value = item.value else { return nil }
                let encodedName = item.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? item.name
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                return "\(encodedName)=\(encodedValue)"
            }
            .joined(separator: "&")

        guard let presignedURL = components.url else {
            return .failure(.presignFailed("Failed to construct URL"))
        }

        return .success(presignedURL.absoluteString)
    }

    // MARK: - File Delete

    func deleteFile(objectKey: String) async -> Result<Void, S3Error> {
        guard config.isValid else {
            return .failure(.invalidConfig("All credential fields must be non-empty"))
        }

        guard let base = baseURL else {
            return .failure(.connectionFailed("Invalid endpoint URL"))
        }

        let url = base.appendingPathComponent(config.bucketName).appendingPathComponent(objectKey)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(config.accessKey, forHTTPHeaderField: "x-amz-access-key")
        request.setValue(ISO8601DateFormatter().string(from: Date()), forHTTPHeaderField: "Date")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.deleteFailed("Invalid response"))
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                return .failure(.deleteFailed("HTTP \(httpResponse.statusCode)"))
            }

            return .success(())
        } catch {
            return .failure(.deleteFailed(error.localizedDescription))
        }
    }

    // MARK: - Lifecycle Rules

    func configureLifecycleRules() async -> Result<Void, S3Error> {
        guard config.isValid else {
            return .failure(.invalidConfig("All credential fields must be non-empty"))
        }

        let xml = buildLifecycleXML()
        return await putBucketLifecycleConfiguration(xml: xml)
    }

    private func buildLifecycleXML() -> String {
        """
        <LifecycleConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
            <Rule>
                <ID>expire-1h</ID>
                <Filter><Prefix>shares/1h/</Prefix></Filter>
                <Status>Enabled</Status>
                <Expiration><Days>1</Days></Expiration>
            </Rule>
            <Rule>
                <ID>expire-1d</ID>
                <Filter><Prefix>shares/1d/</Prefix></Filter>
                <Status>Enabled</Status>
                <Expiration><Days>1</Days></Expiration>
            </Rule>
            <Rule>
                <ID>expire-7d</ID>
                <Filter><Prefix>shares/7d/</Prefix></Filter>
                <Status>Enabled</Status>
                <Expiration><Days>7</Days></Expiration>
            </Rule>
            <Rule>
                <ID>expire-1m</ID>
                <Filter><Prefix>shares/1m/</Prefix></Filter>
                <Status>Enabled</Status>
                <Expiration><Days>30</Days></Expiration>
            </Rule>
        </LifecycleConfiguration>
        """
    }

    private func putBucketLifecycleConfiguration(xml: String) async -> Result<Void, S3Error> {
        guard let base = baseURL else {
            return .failure(.connectionFailed("Invalid endpoint URL"))
        }

        let url = base.appendingPathComponent(config.bucketName)
        guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return .failure(.lifecycleConfigurationFailed("Invalid URL"))
        }
        urlComponents.queryItems = [URLQueryItem(name: "lifecycle", value: nil)]

        guard let lifecycleURL = urlComponents.url else {
            return .failure(.lifecycleConfigurationFailed("Invalid URL"))
        }

        guard let xmlData = xml.data(using: .utf8) else {
            return .failure(.lifecycleConfigurationFailed("Failed to encode XML"))
        }

        var request = URLRequest(url: lifecycleURL)
        request.httpMethod = "PUT"
        request.httpBody = xmlData
        request.setValue(config.accessKey, forHTTPHeaderField: "x-amz-access-key")
        request.setValue(ISO8601DateFormatter().string(from: Date()), forHTTPHeaderField: "Date")
        request.setValue("application/xml", forHTTPHeaderField: "Content-Type")
        request.setValue("\(xmlData.count)", forHTTPHeaderField: "Content-Length")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.lifecycleConfigurationFailed("Invalid response"))
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                return .failure(.lifecycleConfigurationFailed("HTTP \(httpResponse.statusCode)"))
            }

            return .success(())
        } catch {
            return .failure(.lifecycleConfigurationFailed(error.localizedDescription))
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
