import Foundation

// MARK: - Cubbit API URLs

final class CubbitAPIURLs: Sendable {
    static let defaultCoordinatorURL = "https://api.eu00wi.cubbit.services"

    let coordinatorURL: String

    init(coordinatorURL: String = CubbitAPIURLs.defaultCoordinatorURL) {
        var url = coordinatorURL
        while url.hasSuffix("/") { url = String(url.dropLast()) }
        self.coordinatorURL = url
    }

    var iamBaseURL: String { "\(coordinatorURL)/iam/v1" }
    var authBaseURL: String { "\(iamBaseURL)/auth" }
    var signinURL: String { "\(authBaseURL)/signin" }
    var challengeURL: String { "\(signinURL)/challenge" }
    var tokenRefreshURL: String { "\(authBaseURL)/refresh/access" }
    var forgeAccessJWTURL: String { "\(authBaseURL)/forge/access" }
    var accountsMeURL: String { "\(iamBaseURL)/accounts/me" }
    var composerHubBaseURL: String { "\(coordinatorURL)/composer-hub/v1" }
    var projectsURL: String { "\(composerHubBaseURL)/projects" }
    var keyvaultBaseURL: String { "\(coordinatorURL)/keyvault/api/v3" }
    var keysURL: String { "\(keyvaultBaseURL)/keys" }
}

// MARK: - Challenge

struct Challenge: Codable, Sendable {
    let challenge: String
    let salt: String
}

// MARK: - Token

struct Token: Codable, Sendable {
    let token: String
    let exp: Int64
    let expDate: Date

    enum CodingKeys: String, CodingKey {
        case token, exp
        case expDate = "exp_date"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        token = try container.decode(String.self, forKey: .token)
        exp = try container.decode(Int64.self, forKey: .exp)
        let expDateString = try container.decode(String.self, forKey: .expDate)
        guard let date = parseDS3Date(expDateString) else {
            throw DecodingError.dataCorruptedError(forKey: .expDate, in: container, debugDescription: "Invalid date: \(expDateString)")
        }
        expDate = date
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(token, forKey: .token)
        try container.encode(exp, forKey: .exp)
        try container.encode(ds3DateFormatter.string(from: expDate), forKey: .expDate)
    }
}

// MARK: - AccountSession

final class AccountSession: Codable, @unchecked Sendable {
    private(set) var token: Token
    private(set) var refreshToken: String

    enum CodingKeys: String, CodingKey {
        case token, refreshToken
    }

    init(token: Token, refreshToken: String) {
        self.token = token
        self.refreshToken = refreshToken
    }

    func refresh(token: Token, refreshToken: String) {
        self.token = token
        self.refreshToken = refreshToken
    }
}

// MARK: - Account

struct Account: Codable, Sendable {
    let id: String
    let firstName: String
    let lastName: String
    let endpointGateway: String

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case endpointGateway = "endpoint_gateway"
    }
}

// MARK: - DS3ApiKey

struct DS3ApiKey: Codable, Equatable, Sendable {
    let name: String
    let apiKey: String
    let secretKey: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case name
        case apiKey = "api_key"
        case secretKey = "secret_key"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        apiKey = try container.decode(String.self, forKey: .apiKey)
        secretKey = try? container.decode(String.self, forKey: .secretKey)
        if let dateString = try? container.decode(String.self, forKey: .createdAt),
           let date = parseDS3Date(dateString) {
            createdAt = date
        } else {
            createdAt = Date()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(apiKey, forKey: .apiKey)
        try container.encodeIfPresent(secretKey, forKey: .secretKey)
        try container.encode(ds3DateFormatter.string(from: createdAt), forKey: .createdAt)
    }
}

// MARK: - Project

final class Project: Codable, Identifiable, @unchecked Sendable {
    let id: String
    let name: String
    let users: [IAMUser]

    enum CodingKeys: String, CodingKey {
        case id = "project_id"
        case name = "project_name"
        case users
    }

    init(id: String, name: String, users: [IAMUser]) {
        self.id = id
        self.name = name
        self.users = users
    }
}

// MARK: - IAMUser

final class IAMUser: Codable, Identifiable, @unchecked Sendable {
    let id: String
    let username: String
    let isRoot: Bool

    enum CodingKeys: String, CodingKey {
        case id = "user_id"
        case username = "user_name"
        case isRoot = "is_root"
    }

    init(id: String, username: String, isRoot: Bool) {
        self.id = id
        self.username = username
        self.isRoot = isRoot
    }
}
