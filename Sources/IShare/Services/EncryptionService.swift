import Foundation

enum EncryptionError: Error, LocalizedError {
    case encryptionFailed(String)
    case decryptionFailed(String)
    case passwordRequired
    case fileNotFound(URL)

    var errorDescription: String? {
        switch self {
        case .encryptionFailed(let msg): return "Encryption failed: \(msg)"
        case .decryptionFailed(let msg): return "Decryption failed: \(msg)"
        case .passwordRequired: return "Password is required for encryption"
        case .fileNotFound(let url): return "File not found: \(url.path)"
        }
    }
}

struct EncryptionService {
    static let encryptedFileExtension = "enc"

    static func encryptFile(sourceURL: URL, password: String) async -> Result<URL, EncryptionError> {
        guard !password.isEmpty else { return .failure(.passwordRequired) }

        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            return .failure(.fileNotFound(sourceURL))
        }

        let outputURL = sourceURL.appendingPathExtension(encryptedFileExtension)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
        process.arguments = [
            "enc", "-aes-256-cbc", "-pbkdf2", "-iter", "100000",
            "-pass", "pass:\(password)",
            "-in", sourceURL.path,
            "-out", outputURL.path
        ]

        return await withCheckedContinuation { continuation in
            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    continuation.resume(returning: .success(outputURL))
                } else {
                    continuation.resume(returning: .failure(
                        .encryptionFailed("openssl exited with code \(proc.terminationStatus)")
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(returning: .failure(.encryptionFailed(error.localizedDescription)))
            }
        }
    }

    static func decryptFile(sourceURL: URL, password: String, outputURL: URL) async -> Result<Void, EncryptionError> {
        guard !password.isEmpty else { return .failure(.passwordRequired) }

        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            return .failure(.fileNotFound(sourceURL))
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
        process.arguments = [
            "enc", "-d", "-aes-256-cbc", "-pbkdf2", "-iter", "100000",
            "-pass", "pass:\(password)",
            "-in", sourceURL.path,
            "-out", outputURL.path
        ]

        return await withCheckedContinuation { continuation in
            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    continuation.resume(returning: .success(()))
                } else {
                    continuation.resume(returning: .failure(
                        .decryptionFailed("openssl exited with code \(proc.terminationStatus)")
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(returning: .failure(.decryptionFailed(error.localizedDescription)))
            }
        }
    }
}
