#!/bin/bash
set -euo pipefail

APP_NAME="IShare"
SCHEME="IShare"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
RELEASE_DIR="$BUILD_DIR/release"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"
DMG_NAME="$APP_NAME.dmg"
DMG_PATH="$PROJECT_DIR/$DMG_NAME"

clean_artifacts() {
    echo "=== Cleaning previous build artifacts ==="
    rm -rf "$APP_BUNDLE" "$DMG_PATH"
}

build_release() {
    echo "=== Building release binary ==="
    cd "$PROJECT_DIR"
    swift build -c release --arch arm64
}

create_app_bundle() {
    echo "=== Creating .app bundle ==="
    mkdir -p "$APP_BUNDLE/Contents/MacOS"
    mkdir -p "$APP_BUNDLE/Contents/Resources"

    cp "$RELEASE_DIR/$SCHEME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    cp "$PROJECT_DIR/Sources/IShare/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

    cp "$PROJECT_DIR/Sources/IShare/Resources/Icons/"*.png "$APP_BUNDLE/Contents/Resources/"
    cp "$PROJECT_DIR/Sources/IShare/Resources/Icons/IShare.icns" "$APP_BUNDLE/Contents/Resources/"
}

codesign_app() {
    echo "=== Code signing .app bundle (ad-hoc) ==="
    codesign --force --deep --sign - \
        --entitlements "$PROJECT_DIR/IShare.entitlements" \
        --options runtime \
        "$APP_BUNDLE"

    echo "=== Verifying .app bundle ==="
    if [ ! -f "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ]; then
        echo "ERROR: Binary not found in .app bundle"
        exit 1
    fi

    codesign -dv "$APP_BUNDLE" 2>&1 || {
        echo "WARNING: Code signing verification produced non-zero exit (expected for ad-hoc)"
    }

    echo "=== .app bundle created successfully ==="
    echo "Bundle: $APP_BUNDLE"
}

generate_dmg_background() {
    local bg_path="$1"
    /usr/bin/swift - <<'SWIFT_EOF' 2>/dev/null
import Cocoa

let width = 540
let height = 380
let scale: CGFloat = 2.0

guard let ciContext = CIContext(options: nil) else { exit(1) }

let filter = CIFilter(name: "CILinearGradient")!
filter.setValue(CIColor(red: 0.98, green: 0.98, blue: 0.98), forKey: "inputColor0")
filter.setValue(CIColor(red: 0.93, green: 0.93, blue: 0.95), forKey: "inputColor1")
filter.setValue(CIVector(x: 0, y: height), forKey: "inputPoint0")
filter.setValue(CIVector(x: width, y: 0), forKey: "inputPoint1")

guard let outputImage = filter.outputImage else { exit(1) }
let scaleTransform = CGAffineTransform(scaleX: scale, y: scale)
let scaledImage = outputImage.transformed(by: scaleTransform)
let scaledRect = scaledImage.extent

guard let cgImage = ciContext.createCGImage(scaledImage, from: scaledRect) else { exit(1) }

let bitmapRep = NSBitmapImageRep(
    cgImage: cgImage,
    size: NSSize(width: width, height: height)
)
bitmapRep.size = NSSize(width: width, height: height)

guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else { exit(1) }
try pngData.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
SWIFT_EOF
}

create_dmg() {
    local tmp_dir
    tmp_dir=$(mktemp -d)
    local dmg_tmp="$tmp_dir/$APP_NAME"
    mkdir -p "$dmg_tmp"

    echo "=== Creating DMG ==="

    cp -R "$APP_BUNDLE" "$dmg_tmp/"
    ln -s /Applications "$dmg_tmp/Applications"

    cp "$PROJECT_DIR/Icons/output/IShare.icns" "$dmg_tmp/.VolumeIcon.icns"
    /usr/bin/python3 -c "
import Cocoa, sys
ws = Cocoa.NSWorkspace.sharedWorkspace()
img = Cocoa.NSImage.alloc().initWithContentsOfFile_(sys.argv[1])
if img: ws.setIcon_forFile_options_(img, sys.argv[2], 0)
" "$PROJECT_DIR/Icons/output/IShare.icns" "$dmg_tmp" 2>/dev/null || true

    local bg_path="$tmp_dir/background.png"
    if generate_dmg_background "$bg_path" 2>/dev/null; then
        mkdir -p "$dmg_tmp/.background"
        cp "$bg_path" "$dmg_tmp/.background/"
    else
        echo "  (Background image generation skipped \u2014 CI or missing CoreImage support)"
    fi

    local app_size
    app_size=$(du -sk "$APP_BUNDLE" | awk '{print $1}')
    local dmg_size=$(( app_size * 3 / 2 + 10240 ))

    hdiutil create -format UDZO \
      -volname "$APP_NAME" \
      -srcfolder "$dmg_tmp" \
      -size "${dmg_size}k" \
      -fs HFS+ \
      -imagekey zlib-level=9 \
      "$DMG_PATH" -ov

    echo "=== Verifying DMG ==="
    local mount_point
    mount_point=$(hdiutil attach "$DMG_PATH" -nobrowse -mountrandom /tmp 2>&1 | grep "/tmp" | awk '{print $NF}')
    if [ -n "$mount_point" ]; then
        if [ -d "$mount_point/$APP_NAME.app" ] && [ -L "$mount_point/Applications" ]; then
            echo "  \u2713 $APP_NAME.app present in DMG"
            echo "  \u2713 Applications symlink present"
        else
            echo "  WARNING: DMG contents incomplete"
            ls -la "$mount_point"
        fi
        hdiutil detach "$mount_point" -quiet
    else
        echo "  WARNING: Could not mount DMG for verification"
    fi

    rm -rf "$tmp_dir"

    echo "=== DMG created successfully ==="
    echo "DMG: $DMG_PATH ($(du -h "$DMG_PATH" | awk '{print $1}'))"
}

upload_dmg() {
    echo "=== Uploading DMG to Cubbit DS3 ==="
    local version
    version=$(defaults read "$PROJECT_DIR/Sources/IShare/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "latest")
    local object_key="IShare/IShare-${version}.dmg"

    echo "Uploading to packages/${object_key}..."
    local download_url
    download_url=$(/usr/bin/python3 "$PROJECT_DIR/scripts/upload-dmg.py" "$DMG_PATH" "$object_key" 2>&1 | tail -1)

    if [ -n "$download_url" ] && echo "$download_url" | grep -q "^https://"; then
        echo "  \u2713 Upload successful"
        echo "  Download URL: $download_url"
        /usr/bin/python3 -c "
import sys
path = sys.argv[1]
url = sys.argv[2]
with open(path) as f:
    content = f.read()
content = content.replace('DOWNLOAD_LINK_PLACEHOLDER', url)
with open(path, 'w') as f:
    f.write(content)
" "$PROJECT_DIR/README.md" "$download_url"
        echo "  \u2713 README.md updated with download URL"
    else
        echo "  WARNING: Upload may have failed"
    fi
}

cd "$PROJECT_DIR"

if [ "${1:-}" = "--dmg" ]; then
    clean_artifacts
    build_release
    create_app_bundle
    codesign_app
    create_dmg
    upload_dmg
else
    clean_artifacts
    build_release
    create_app_bundle
    codesign_app
    echo ""
    echo "=== Build complete ==="
    echo "App bundle: $APP_BUNDLE"
    echo "To create DMG, run: bash build-release.sh --dmg"

fi
