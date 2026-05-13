import SwiftUI

extension Image {
    static var menuBar: Image { Image("menubar-icon", bundle: .module) }
    static var statusSuccess: Image { Image("status-success", bundle: .module) }
    static var statusError: Image { Image("status-error", bundle: .module) }
    static var statusUploading: Image { Image("status-uploading", bundle: .module) }
}
