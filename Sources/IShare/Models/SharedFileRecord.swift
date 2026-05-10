import Foundation

struct SharedFileRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let fileName: String
    let durationRawValue: String
    let uploadTimestamp: Date
    let objectKey: String
    let isEncrypted: Bool
    let presignedURL: String?

    var duration: ShareDuration {
        ShareDuration(rawValue: durationRawValue) ?? .oneDay
    }

    var remainingSeconds: TimeInterval {
        guard duration.seconds > 0 else { return -1 }
        let elapsed = Date().timeIntervalSince(uploadTimestamp)
        return max(0, TimeInterval(duration.seconds) - elapsed)
    }

    var isExpired: Bool {
        guard duration.seconds > 0 else { return false }
        return Date() >= uploadTimestamp.addingTimeInterval(TimeInterval(duration.seconds))
    }

    var remainingTimeLabel: String {
        guard duration.seconds > 0 else { return "Never expires" }
        let rem = Int(remainingSeconds)
        if rem <= 0 { return "Expired" }
        let hours = rem / 3600
        let minutes = (rem % 3600) / 60
        if hours > 24 { return "\(hours / 24)d \(hours % 24)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    init(
        id: UUID = UUID(),
        fileName: String,
        duration: ShareDuration,
        uploadTimestamp: Date = Date(),
        objectKey: String,
        isEncrypted: Bool,
        presignedURL: String? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.durationRawValue = duration.rawValue
        self.uploadTimestamp = uploadTimestamp
        self.objectKey = objectKey
        self.isEncrypted = isEncrypted
        self.presignedURL = presignedURL
    }
}
