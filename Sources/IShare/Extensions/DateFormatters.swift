import Foundation

let ds3DateFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

let ds3DateFormatterFallback: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()

func parseDS3Date(_ string: String) -> Date? {
    ds3DateFormatter.date(from: string) ?? ds3DateFormatterFallback.date(from: string)
}
