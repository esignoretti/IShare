import Foundation
import CommonCrypto

extension Data {
    func hmacSHA256(key: Data) -> Data {
        var mac = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        key.withUnsafeBytes { keyBytes in
            self.withUnsafeBytes { dataBytes in
                CCHmac(
                    CCHmacAlgorithm(kCCHmacAlgSHA256),
                    keyBytes.baseAddress, key.count,
                    dataBytes.baseAddress, self.count,
                    &mac
                )
            }
        }
        return Data(mac)
    }

    var sha256: Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        _ = self.withUnsafeBytes { dataBytes in
            CC_SHA256(dataBytes.baseAddress, CC_LONG(self.count), &hash)
        }
        return Data(hash)
    }

    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

extension String {
    var sha256Hex: String {
        Data(utf8).sha256.hexString
    }

    func hmacSHA256(key: Data) -> Data {
        Data(utf8).hmacSHA256(key: key)
    }

    func hmacSHA256(key: String) -> Data {
        Data(utf8).hmacSHA256(key: Data(key.utf8))
    }

    var uriEncoded: String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }
}

func sigV4SigningKey(secretKey: String, dateStamp: String, region: String, service: String) -> Data {
    let kSecret = Data("AWS4\(secretKey)".utf8)
    let kDate = dateStamp.hmacSHA256(key: kSecret)
    let kRegion = region.hmacSHA256(key: kDate)
    let kService = service.hmacSHA256(key: kRegion)
    let kSigning = "aws4_request".hmacSHA256(key: kService)
    return kSigning
}

func sigV4DateStamp(from date: Date = Date()) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter.string(from: date)
}

func sigV4AmzDate(from date: Date = Date()) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter.string(from: date)
}
