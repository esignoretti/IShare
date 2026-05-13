import SwiftUI

extension Image {
    private static func load(_ name: String) -> Image {
        if let path = Bundle.main.path(forResource: name, ofType: "png"),
           let nsImage = NSImage(contentsOfFile: path) {
            return Image(nsImage: nsImage)
        }
        return Image(systemName: "questionmark.square")
    }

    static var menuBar: Image { load("menubar-icon") }
    static var statusSuccess: Image { load("status-success") }
    static var statusError: Image { load("status-error") }
    static var statusUploading: Image { load("status-uploading") }
}
