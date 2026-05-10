import Foundation

struct RecipientInfo {
    var recipientName: String = ""
    var recipientEmail: String = ""
    var personalMessage: String = ""
}

enum ShareDuration: String, CaseIterable, Identifiable {
    case oneHour = "1h"
    case oneDay = "1d"
    case sevenDays = "7d"
    case oneMonth = "1m"
    case forever = "forever"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .oneHour: return "1 Hour"
        case .oneDay: return "1 Day"
        case .sevenDays: return "7 Days"
        case .oneMonth: return "1 Month"
        case .forever: return "Never Expires"
        }
    }

    var seconds: Int {
        switch self {
        case .oneHour: return 3600
        case .oneDay: return 86400
        case .sevenDays: return 604800
        case .oneMonth: return 2_592_000
        case .forever: return 0
        }
    }
}

struct ShareItem: Identifiable {
    let id = UUID()
    var fileURL: URL
    let isDirectory: Bool
    var compress: Bool
    var duration: ShareDuration = .oneDay
    var objectKey: String?
    var presignedURL: String?
    var progress: Double = 0.0
    var state: ShareState = .pending
    var recipientInfo: RecipientInfo = RecipientInfo()
    var encryptionPassword: String = ""

    var isEncrypted: Bool { !encryptionPassword.isEmpty }

    var hasRecipient: Bool {
        !recipientInfo.recipientEmail.isEmpty
    }

    var displayName: String {
        fileURL.lastPathComponent
    }

    init(fileURL: URL, compress: Bool = false) {
        self.fileURL = fileURL
        self.isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        self.compress = self.isDirectory ? true : compress
    }
}

enum ShareState: Equatable {
    case pending
    case compressing
    case encrypting
    case uploading
    case generatingURL
    case complete
    case failed(String)
}
