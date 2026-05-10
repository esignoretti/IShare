# IShare

macOS native menu bar app for sharing large files via S3-compatible storage. Right-click any file or folder in Finder, set a duration, and get a pre-signed URL on your clipboard — in seconds.

## Features

- **Finder integration** — Share any file or directory from Finder's Quick Actions / Services menu
- **Directory compression** — Folders are automatically zipped before upload
- **Flexible duration** — Choose share expiration: 1h, 1d, 7d, 1m, or never
- **Password encryption** — Optionally encrypt files with AES-256-CBC before upload (password sent out-of-band)
- **Recipient notification** — Optional recipient fields open system Mail with a pre-composed draft
- **S3 lifecycle cleanup** — Expired files are auto-deleted by S3 lifecycle rules
- **Menu bar tray** — View all active shares, copy links, or delete files directly from the menu bar
- **Persistent history** — Share records survive app restarts

## Requirements

- macOS 14 (Sonoma) or later
- An S3-compatible storage endpoint (e.g., Cubbit DS3)
- S3 access key and secret key

## Build

```bash
# Build the .app bundle
bash build-release.sh

# Build + create distributable .dmg
bash build-release.sh --dmg
```

The project uses Swift Package Manager with no external dependencies.

## Usage

1. Launch IShare — you'll be prompted to configure S3 credentials
2. Enter your S3 endpoint URL, access key, secret key, and bucket name
3. Right-click any file or folder in Finder → Services → **Share with IShare**
4. Set duration, optionally encrypt and add recipient info
5. The pre-signed URL is copied to your clipboard automatically

You can also press `⌘⇧N` or use **File → Share File...** from the menu bar.

## Configuration

Credentials are stored securely in the macOS Keychain. The app auto-creates the S3 bucket if it doesn't exist. Use **File → S3 Configuration...** or `⌘,` to update credentials.

## License

MIT
