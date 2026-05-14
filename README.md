# IShare

macOS native menu bar app for sharing large files via Cubbit DS3. Right-click any file or folder in Finder, set a duration, and get a pre-signed URL on your clipboard — in seconds.

## Download

[Download Latest DMG](https://s3.cubbit.eu/packages/IShare/IShare-1.0.1.dmg?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=lLhwVfQ7Ajet2GLTZPWdDp%2FS46qqAt2U%2F20260514%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20260514T183846Z&X-Amz-Expires=7776000&X-Amz-SignedHeaders=host&X-Amz-Signature=048e04179b0565d9131cf1b30fe9eaec107eca13e2246184f5f8eba452a70fce)

## Features

- **Cubbit DS3 auth** — Sign in with your Cubbit account email and password
- **Finder integration** — Share any file or directory from Finder's Quick Actions / Services menu
- **Directory compression** — Folders are automatically zipped before upload
- **Flexible duration** — Choose share expiration: 1h, 1d, 7d, 1m, or never
- **Password encryption** — Optionally encrypt files with AES-256-CBC before upload (password sent out-of-band)
- **Recipient notification** — Optional recipient fields open system Mail with a pre-composed draft
- **S3 lifecycle cleanup** — Expired files are auto-deleted by lifecycle rules
- **Menu bar tray** — View all active shares, copy links, or delete files directly from the menu bar
- **Drag & drop** — Drop files onto the main window to share
- **Persistent history** — Share records survive app restarts

## Requirements

- macOS 14 (Sonoma) or later
- A Cubbit DS3 account

## Build

```bash
# Build the .app bundle
bash build-release.sh

# Build + create distributable .dmg + upload to Cubbit DS3
bash build-release.sh --dmg
```

The project uses Swift Package Manager with no external dependencies.

## Usage

1. Launch IShare — you'll be prompted to sign in with your Cubbit account
2. Select a project and confirm the bucket name
3. Right-click any file or folder in Finder → Services → **Share with IShare**
4. Set duration, optionally encrypt and add recipient info
5. The pre-signed URL is copied to your clipboard automatically

You can also press `⌘⇧N`, use **File → Share File...** from the menu bar, or drag files onto the main window.

## Configuration

Session and API keys are persisted securely. Use **File → DS3 Configuration...** or `⌘,` to update bucket settings.

## License

MIT
