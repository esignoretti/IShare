import Foundation

struct ShareService {
    private let s3Service: S3Service
    private let shareHistoryStore: ShareHistoryStore

    init(s3Service: S3Service, shareHistoryStore: ShareHistoryStore = ShareHistoryStore()) {
        self.s3Service = s3Service
        self.shareHistoryStore = shareHistoryStore
    }

    func compress(sourceURL: URL, outputURL: URL) async -> Result<URL, ShareError> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = [
            "-c", "-k", "--sequesterRsrc",
            sourceURL.path,
            outputURL.path
        ]

        guard FileManager.default.fileExists(atPath: "/usr/bin/ditto") else {
            return .failure(.compressionFailed("ditto not found at /usr/bin/ditto"))
        }

        return await withCheckedContinuation { continuation in
            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    continuation.resume(returning: .success(outputURL))
                } else {
                    continuation.resume(returning: .failure(
                        .compressionFailed("ditto exited with code \(proc.terminationStatus)")
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(returning: .failure(.compressionFailed(error.localizedDescription)))
            }
        }
    }

    func share(_ item: ShareItem, onUpdate: @escaping (ShareItem) -> Void) async -> ShareItem {
        var mutableItem = item

        if mutableItem.compress {
            mutableItem.state = .compressing
            onUpdate(mutableItem)

            let tempDir = FileManager.default.temporaryDirectory
            let zipName = mutableItem.fileURL.lastPathComponent + ".zip"
            let zipURL = tempDir.appendingPathComponent(zipName)

            let result = await compress(sourceURL: mutableItem.fileURL, outputURL: zipURL)
            switch result {
            case .success(let compressedURL):
                mutableItem.fileURL = compressedURL
            case .failure(let error):
                mutableItem.state = .failed(error.localizedDescription)
                onUpdate(mutableItem)
                return mutableItem
            }
        }

        if mutableItem.isEncrypted {
            mutableItem.state = .encrypting
            onUpdate(mutableItem)

            let encryptResult = await EncryptionService.encryptFile(
                sourceURL: mutableItem.fileURL,
                password: mutableItem.encryptionPassword
            )

            switch encryptResult {
            case .success(let encryptedURL):
                mutableItem.fileURL = encryptedURL
            case .failure(let error):
                mutableItem.state = .failed(error.localizedDescription)
                onUpdate(mutableItem)
                return mutableItem
            }
        }

        mutableItem.state = .uploading
        onUpdate(mutableItem)

        let uploadResult = await s3Service.uploadFile(
            fileURL: mutableItem.fileURL,
            duration: mutableItem.duration.rawValue,
            progressHandler: { progress in
                mutableItem.progress = progress
                onUpdate(mutableItem)
            }
        )

        switch uploadResult {
        case .success(let objectKey):
            mutableItem.objectKey = objectKey
        case .failure(let error):
            mutableItem.state = .failed(error.localizedDescription)
            onUpdate(mutableItem)
            return mutableItem
        }

        mutableItem.state = .generatingURL
        onUpdate(mutableItem)

        guard let objectKey = mutableItem.objectKey else {
            mutableItem.state = .failed("Missing object key after upload")
            onUpdate(mutableItem)
            return mutableItem
        }

        let expirySeconds = mutableItem.duration.seconds == 0 ? 315_360_000 : mutableItem.duration.seconds

        let presignResult = s3Service.generatePresignedURL(
            objectKey: objectKey,
            durationSeconds: expirySeconds
        )

        switch presignResult {
        case .success(let url):
            mutableItem.presignedURL = url
            mutableItem.state = .complete
        case .failure(let error):
            mutableItem.state = .failed(error.localizedDescription)
        }

        if mutableItem.state == .complete, let objectKey = mutableItem.objectKey {
            let cleanName = mutableItem.fileURL.lastPathComponent
                .replacingOccurrences(of: ".enc", with: "")
                .replacingOccurrences(of: ".zip", with: "")
            let record = SharedFileRecord(
                fileName: cleanName,
                duration: mutableItem.duration,
                objectKey: objectKey,
                isEncrypted: mutableItem.isEncrypted,
                presignedURL: mutableItem.presignedURL
            )
            shareHistoryStore.add(record)
        }

        onUpdate(mutableItem)
        return mutableItem
    }

    static func cleanupTempFiles(for item: ShareItem) {
        if item.compress {
            let tempDir = FileManager.default.temporaryDirectory
            let tempFileURL = item.fileURL
            if tempFileURL.path.hasPrefix(tempDir.path) {
                try? FileManager.default.removeItem(at: tempFileURL)
            }
        }

        if item.isEncrypted {
            let tempDir = FileManager.default.temporaryDirectory
            if item.fileURL.path.hasPrefix(tempDir.path) {
                try? FileManager.default.removeItem(at: item.fileURL)
            }
        }
    }
}

enum ShareError: Error, LocalizedError {
    case compressionFailed(String)
    case uploadFailed(String)
    case urlGenerationFailed(String)
    case encryptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .compressionFailed(let msg): return "Compression failed: \(msg)"
        case .uploadFailed(let msg): return "Upload failed: \(msg)"
        case .urlGenerationFailed(let msg): return "URL generation failed: \(msg)"
        case .encryptionFailed(let msg): return "Encryption failed: \(msg)"
        }
    }
}
