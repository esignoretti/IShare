import Foundation

extension Data {
    /// Returns a hex-encoded string representation of the data.
    var hexEncodedString: String {
        map { String(format: "%02hhx", $0) }.joined()
    }
}
