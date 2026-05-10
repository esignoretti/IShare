# IShare Requirements

> macOS native app for sharing large files via S3-compatible storage (Cubbit DS3)

---

## REQ-001: S3 Credential Configuration
The app shall provide a setup UI for entering S3 credentials: endpoint URL, access key, secret key, and bucket name. On first run, if the specified bucket does not exist, the app must create it automatically.

## REQ-002: Quick Actions Integration
The app shall integrate with macOS Finder's right-click Quick Actions menu to allow sharing files and directories directly from Finder.

## REQ-003: Compression
The app shall offer to compress files before upload using zip (default). Directories must always be compressed to a single zip file before upload. Single files may optionally skip compression.

## REQ-004: Password Encryption
The app shall offer optional password-based encryption before upload. When enabled, the file shall be encrypted with the provided password before being uploaded to S3. The password is communicated out-of-band (not included in any notification email).

## REQ-005: Recipient Information & Personal Message
The app shall optionally collect recipient name, recipient email address, and a personal message from the sender during the share flow. This information is used to compose the notification email.

## REQ-006: Email Notification via System Mail App
The app shall open the system default mail client with a pre-composed email draft containing: recipient email address, subject line with file name, and body including the pre-signed URL, expiry date, sender's personal message, and file name. The email shall NOT contain the encryption password.

## REQ-007: Expiration Durations
The app shall support the following share durations: 1 hour, 1 day, 7 days, 1 month, and forever. The selected duration determines both the pre-signed URL expiration and the S3 lifecycle rule applied to the uploaded object.

## REQ-008: S3 Upload & Pre-signed URL
The app shall upload the file (compressed if applicable) to S3 under a prefix organized by duration (`shares/1h/`, `shares/1d/`, `shares/7d/`, `shares/1m/`, `shares/forever/`), generate a pre-signed URL matching the selected duration, and copy the URL to the clipboard.

## REQ-009: Lifecycle Management
The app shall configure S3 lifecycle rules on the bucket to automatically delete objects after their duration expires. Files shared as "forever" shall have no lifecycle rule.

## REQ-010: Menu Bar Tray
The app shall live in the macOS menu bar with an icon. Clicking it shall show a list of all shared files with: filename, duration, remaining time, a link to copy the pre-signed URL again, and a delete button to remove the file immediately from S3 and the list.

## REQ-011: Distribution
The app shall be distributed as a `.dmg` file containing the `.app` bundle.

## REQ-012: Persistent State
The app shall persist the list of shared files locally so the tray list survives app restarts.
