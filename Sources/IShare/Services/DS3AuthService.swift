import Foundation
import CryptoKit

enum DS3AuthError: Error, LocalizedError {
    case invalidURL(String)
    case serverError(Int, String)
    case jsonConversion
    case encoding
    case loggedOut
    case tokenExpired
    case missing2FA
    case notConfigured
    case noProjects
    case noIAMUser
    case missingSecretKey
    case persistence(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let msg): return "Invalid URL: \(msg)"
        case .serverError(let code, let body): return "Server error HTTP \(code): \(body)"
        case .jsonConversion: return "Failed to parse server response"
        case .encoding: return "Encoding error"
        case .loggedOut: return "Not logged in"
        case .tokenExpired: return "Session expired"
        case .missing2FA: return "Two-factor authentication code required"
        case .notConfigured: return "DS3 authentication not configured"
        case .noProjects: return "No projects found in your account"
        case .noIAMUser: return "No IAM user found for the selected project"
        case .missingSecretKey: return "API key has no secret key"
        case .persistence(let msg): return "Failed to save session: \(msg)"
        }
    }
}

@MainActor
final class DS3AuthService {
    private let urls: CubbitAPIURLs
    private var session: AccountSession?
    private var account: Account?
    private var apiKey: DS3ApiKey?

    var isLoggedIn: Bool { session != nil }

    var s3AccessKey: String? { apiKey?.apiKey }
    var s3SecretKey: String? { apiKey?.secretKey }
    var endpointGateway: String? { account?.endpointGateway }
    var currentAccount: Account? { account }
    var currentSession: AccountSession? { session }
    var currentApiKey: DS3ApiKey? { apiKey }

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    // MARK: - Persistence

    private var persistenceURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("com.isare.app")
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport
    }

    func saveToDisk() throws {
        guard let session, let account, let apiKey else { throw DS3AuthError.loggedOut }
        let wrapper = PersistedAuth(session: session, account: account, apiKey: apiKey)
        let data = try encoder.encode(wrapper)
        try data.write(to: persistenceURL.appendingPathComponent("ds3auth.json"))
    }

    func loadFromDisk() throws -> (AccountSession, Account, DS3ApiKey) {
        let fileURL = persistenceURL.appendingPathComponent("ds3auth.json")
        guard FileManager.default.fileExists(atPath: fileURL.path) else { throw DS3AuthError.loggedOut }
        let data = try Data(contentsOf: fileURL)
        let wrapper = try tryDecode(PersistedAuth.self, from: data, tag: "loadFromDisk")
        return (wrapper.session, wrapper.account, wrapper.apiKey)
    }

    func deleteFromDisk() {
        let fileURL = persistenceURL.appendingPathComponent("ds3auth.json")
        try? FileManager.default.removeItem(at: fileURL)
    }

    init(urls: CubbitAPIURLs = CubbitAPIURLs()) {
        self.urls = urls
    }

    private func debugLog(_ tag: String, data: Data, response: URLResponse) {
        #if DEBUG
        let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        print("[DS3Auth] \(tag): HTTP \(code) \(body.prefix(500))")
        #endif
    }

    private func tryDecode<T: Decodable>(_ type: T.Type, from data: Data, tag: String) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            throw DS3AuthError.serverError(-1, "\(tag): \(error.localizedDescription) — body: \(body.prefix(300))")
        }
    }

    // MARK: - Login

    func login(email: String, password: String, tfaCode: String? = nil, tenant: String? = nil) async throws {
        let challenge = try await getChallenge(email: email, tenant: tenant)
        let signedChallenge = try signChallenge(challenge: challenge, password: password)
        let session = try await getAccountSession(email: email, signedChallenge: signedChallenge, tfaCode: tfaCode, tenant: tenant)
        self.session = session

        let account = try await fetchAccountInfo()
        self.account = account

        let projects = try await fetchProjects()
        guard let firstProject = projects.first else { throw DS3AuthError.noProjects }
        guard let rootUser = firstProject.users.first(where: { $0.isRoot }) ?? firstProject.users.first else {
            throw DS3AuthError.noIAMUser
        }

        let apiKey = try await loadOrCreateApiKey(for: rootUser, projectName: firstProject.name)
        self.apiKey = apiKey
    }

    func logout() {
        session = nil
        account = nil
        apiKey = nil
        deleteFromDisk()
    }

    // MARK: - Refresh

    func refreshIfNeeded() async throws {
        guard let session else { throw DS3AuthError.loggedOut }
        guard Date() >= session.token.expDate else { return }

        guard let url = URL(string: urls.tokenRefreshURL) else { throw DS3AuthError.invalidURL(urls.tokenRefreshURL) }
        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = [
            "Content-Type": "application/json",
            "Cookie": "_refresh=\(session.refreshToken)"
        ]
        request.httpShouldHandleCookies = true
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw DS3AuthError.tokenExpired
        }

        guard let fields = httpResponse.allHeaderFields as? [String: String] else { throw DS3AuthError.serverError(-1, "no headers") }
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: url)
        guard let newRefreshToken = cookies.first(where: { $0.name == "_refresh" })?.value else {
            throw DS3AuthError.serverError(-1, "no refresh cookie")
        }
        debugLog("refresh", data: data, response: response)
        let newToken = try tryDecode(Token.self, from: data, tag: "refresh")
        session.refresh(token: newToken, refreshToken: newRefreshToken)
    }

    // MARK: - Challenge-Response

    private func getChallenge(email: String, tenant: String?) async throws -> Challenge {
        guard let url = URL(string: urls.challengeURL) else { throw DS3AuthError.invalidURL(urls.challengeURL) }
        let body = ChallengeRequest(email: email, tenantId: tenant)
        let bodyData = try encoder.encode(body)

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw DS3AuthError.serverError(code, String(data: data, encoding: .utf8) ?? "")
        }
        debugLog("getChallenge", data: data, response: response)
        return try tryDecode(Challenge.self, from: data, tag: "challenge")
    }

    private func signChallenge(challenge: Challenge, password: String) throws -> String {
        guard let passwordData = password.data(using: .utf8),
              let saltData = challenge.salt.data(using: .utf8) else {
            throw DS3AuthError.encoding
        }
        var sha = SHA256()
        sha.update(data: passwordData + saltData)
        let seed = Data(sha.finalize())
        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
        guard let challengeData = challenge.challenge.data(using: .utf8) else {
            throw DS3AuthError.encoding
        }
        return try privateKey.signature(for: challengeData).base64EncodedString()
    }

    private func getAccountSession(email: String, signedChallenge: String, tfaCode: String?, tenant: String?) async throws -> AccountSession {
        guard let url = URL(string: urls.signinURL) else { throw DS3AuthError.invalidURL(urls.signinURL) }
        let loginReq = LoginRequest(email: email, signedChallenge: signedChallenge, tfaCode: tfaCode, tenantId: tenant)
        let bodyData = try encoder.encode(loginReq)

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw DS3AuthError.serverError(-1, "no response") }

        if httpResponse.statusCode == 200 {
            debugLog("getAccountSession", data: data, response: response)
            let token = try tryDecode(Token.self, from: data, tag: "session")
            guard let fields = httpResponse.allHeaderFields as? [String: String] else {
                throw DS3AuthError.serverError(-1, "no headers")
            }
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: url)
            guard let refreshToken = cookies.first(where: { $0.name == "_refresh" })?.value else {
                throw DS3AuthError.serverError(-1, "no refresh cookie")
            }
            return AccountSession(token: token, refreshToken: refreshToken)
        } else if httpResponse.statusCode == 403 {
            if let body = try? decoder.decode(Missing2FAResponse.self, from: data),
               body.message.contains("two factor") {
                throw DS3AuthError.missing2FA
            }
            throw DS3AuthError.serverError(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "")
        } else {
            throw DS3AuthError.serverError(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
    }

    // MARK: - Account Info

    private func fetchAccountInfo() async throws -> Account {
        try await refreshIfNeeded()
        guard let session else { throw DS3AuthError.loggedOut }
        guard let url = URL(string: urls.accountsMeURL) else { throw DS3AuthError.invalidURL(urls.accountsMeURL) }

        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(session.token.token)"
        ]
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw DS3AuthError.serverError(code, String(data: data, encoding: .utf8) ?? "")
        }
        return try tryDecode(Account.self, from: data, tag: "accountInfo")
    }

    // MARK: - Projects

    private func fetchProjects() async throws -> [Project] {
        try await refreshIfNeeded()
        guard let session else { throw DS3AuthError.loggedOut }
        guard let url = URL(string: urls.projectsURL) else { throw DS3AuthError.invalidURL(urls.projectsURL) }

        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(session.token.token)"
        ]
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw DS3AuthError.serverError(code, String(data: data, encoding: .utf8) ?? "")
        }
        return try tryDecode([Project].self, from: data, tag: "projects")
    }

    // MARK: - API Keys

    private func forgeIAMToken(for user: IAMUser) async throws -> Token {
        try await refreshIfNeeded()
        guard let session else { throw DS3AuthError.loggedOut }
        guard let url = URL(string: "\(urls.forgeAccessJWTURL)?user_id=\(user.id)") else {
            throw DS3AuthError.invalidURL(urls.forgeAccessJWTURL)
        }

        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = [
            "Content-Type": "application/json",
            "Cookie": "_refresh=\(session.refreshToken)"
        ]
        request.httpShouldHandleCookies = true
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw DS3AuthError.tokenExpired
        }

        guard let fields = httpResponse.allHeaderFields as? [String: String] else {
            throw DS3AuthError.serverError(-1, "no headers")
        }
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: url)
        if let newRefresh = cookies.first(where: { $0.name == "_refresh" })?.value {
            session.refresh(token: session.token, refreshToken: newRefresh)
        }

        debugLog("forgeIAMToken", data: data, response: response)
        return try tryDecode(Token.self, from: data, tag: "forgeIAMToken")
    }

    private func loadOrCreateApiKey(for user: IAMUser, projectName: String) async throws -> DS3ApiKey {
        let iamToken = try await forgeIAMToken(for: user)
        let apiKeyName = "IShare(\(user.username)_\(projectName.lowercased().replacingOccurrences(of: " ", with: "_")))"

        let remoteKeys = try await fetchRemoteKeys(for: user, iamToken: iamToken)
        if let existing = remoteKeys.first(where: { $0.name == apiKeyName }) {
            return existing
        }

        return try await generateApiKey(for: user, iamToken: iamToken, name: apiKeyName)
    }

    private func fetchRemoteKeys(for user: IAMUser, iamToken: Token) async throws -> [DS3ApiKey] {
        guard let url = URL(string: "\(urls.keysURL)?user_id=\(user.id)") else {
            throw DS3AuthError.invalidURL(urls.keysURL)
        }
        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = ["Authorization": "Bearer \(iamToken.token)"]
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw DS3AuthError.serverError(code, String(data: data, encoding: .utf8) ?? "")
        }
        debugLog("fetchRemoteKeys", data: data, response: response)
        return try tryDecode([DS3ApiKey].self, from: data, tag: "fetchRemoteKeys")
    }

    private func generateApiKey(for user: IAMUser, iamToken: Token, name: String) async throws -> DS3ApiKey {
        guard let url = URL(string: "\(urls.keysURL)/\(name)?user_id=\(user.id)") else {
            throw DS3AuthError.invalidURL(urls.keysURL)
        }
        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = ["Authorization": "Bearer \(iamToken.token)"]
        request.httpMethod = "POST"

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw DS3AuthError.serverError(code, String(data: data, encoding: .utf8) ?? "")
        }
        return try tryDecode(DS3ApiKey.self, from: data, tag: "generateApiKey")
    }
}

// MARK: - Request DTOs

private struct ChallengeRequest: Codable {
    let email: String
    let tenantId: String?

    enum CodingKeys: String, CodingKey {
        case email
        case tenantId = "tenant_id"
    }
}

private struct LoginRequest: Codable {
    let email: String
    let signedChallenge: String
    let tfaCode: String?
    let tenantId: String?

    enum CodingKeys: String, CodingKey {
        case email
        case signedChallenge = "signed_challenge"
        case tfaCode = "tfa_code"
        case tenantId = "tenant_id"
    }
}

private struct Missing2FAResponse: Codable {
    let message: String
}

private struct PersistedAuth: Codable {
    let session: AccountSession
    let account: Account
    let apiKey: DS3ApiKey
}
