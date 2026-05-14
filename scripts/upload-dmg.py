#!/usr/bin/env python3
"""Upload a file to Cubbit DS3 using SigV4, then print a presigned download URL."""
import sys, os, hashlib, hmac, datetime, urllib.request, urllib.parse, mimetypes
from pathlib import Path

ACCESS_KEY = os.environ.get("DS3_ACCESS_KEY", "lLhwVfQ7Ajet2GLTZPWdDp/S46qqAt2U")
SECRET_KEY = os.environ.get("DS3_SECRET_KEY", "XCwkS4uQMdl4MWih944Pthzd2EqRNd2sVkr3ZjM/NEk=")
BUCKET = "packages"
ENDPOINT = "https://s3.cubbit.eu"
REGION = "us-east-1"
SERVICE = "s3"

RFC3986_UNRESERVED = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"

def uri_encode(s):
    return urllib.parse.quote(s, safe=RFC3986_UNRESERVED)
    return hashlib.sha256(data).digest()

def hex_sha256(data):
    return hashlib.sha256(data).hexdigest()

def hmac_sha256(key, msg):
    return hmac.new(key, msg.encode("utf-8"), hashlib.sha256).digest()

def sigv4_signing_key(secret_key, date_stamp, region, service):
    k = hmac_sha256(f"AWS4{secret_key}".encode(), date_stamp)
    k = hmac_sha256(k, region)
    k = hmac_sha256(k, service)
    return hmac_sha256(k, "aws4_request")

def sign(method, path, headers, body, timestamp):
    amz_date = timestamp.strftime("%Y%m%dT%H%M%SZ")
    date_stamp = timestamp.strftime("%Y%m%d")
    credential_scope = f"{date_stamp}/{REGION}/{SERVICE}/aws4_request"

    host = urllib.parse.urlparse(ENDPOINT).netloc
    canonical_uri = path
    canonical_qs = ""
    canonical_headers = f"host:{host}\n"
    signed_headers = "host"
    payload_hash = hex_sha256(body)
    canonical_request = f"{method}\n{canonical_uri}\n{canonical_qs}\n{canonical_headers}\n{signed_headers}\n{payload_hash}"
    string_to_sign = f"AWS4-HMAC-SHA256\n{amz_date}\n{credential_scope}\n{hex_sha256(canonical_request.encode())}"
    signing_key = sigv4_signing_key(SECRET_KEY, date_stamp, REGION, SERVICE)
    signature = hmac_sha256(signing_key, string_to_sign).hex()
    auth = f"AWS4-HMAC-SHA256 Credential={ACCESS_KEY}/{credential_scope}, SignedHeaders={signed_headers}, Signature={signature}"
    headers["X-Amz-Date"] = amz_date
    headers["x-amz-content-sha256"] = payload_hash
    headers["Authorization"] = auth

def presign(method, path, expires_seconds, timestamp):
    amz_date = timestamp.strftime("%Y%m%dT%H%M%SZ")
    date_stamp = timestamp.strftime("%Y%m%d")
    credential_scope = f"{date_stamp}/{REGION}/{SERVICE}/aws4_request"
    host = urllib.parse.urlparse(ENDPOINT).netloc

    params = [
        ("X-Amz-Algorithm", "AWS4-HMAC-SHA256"),
        ("X-Amz-Credential", f"{ACCESS_KEY}/{credential_scope}"),
        ("X-Amz-Date", amz_date),
        ("X-Amz-Expires", str(expires_seconds)),
        ("X-Amz-SignedHeaders", "host"),
    ]
    params.sort()
    canonical_qs = "&".join(f"{uri_encode(k)}={uri_encode(v)}" for k, v in params)
    canonical_headers = f"host:{host}\n"
    signed_headers = "host"
    payload_hash = "UNSIGNED-PAYLOAD"
    canonical_request = f"{method}\n{path}\n{canonical_qs}\n{canonical_headers}\n{signed_headers}\n{payload_hash}"
    string_to_sign = f"AWS4-HMAC-SHA256\n{amz_date}\n{credential_scope}\n{hex_sha256(canonical_request.encode())}"
    signing_key = sigv4_signing_key(SECRET_KEY, date_stamp, REGION, SERVICE)
    signature = hmac_sha256(signing_key, string_to_sign).hex()
    qs = canonical_qs + f"&X-Amz-Signature={signature}"
    return f"{ENDPOINT}{path}?{qs}"

def main():
    filepath = sys.argv[1]
    object_key = sys.argv[2] if len(sys.argv) > 2 else f"IShare/{Path(filepath).name}"

    path = f"/{BUCKET}/{object_key}"
    url = f"{ENDPOINT}{path}"

    timestamp = datetime.datetime.now(datetime.timezone.utc)

    with open(filepath, "rb") as f:
        body = f.read()

    content_type = mimetypes.guess_type(filepath)[0] or "application/octet-stream"
    headers = {"Content-Type": content_type, "Content-Length": str(len(body))}

    print(f"=== Uploading {filepath} to {url} ===")
    headers["x-amz-acl"] = "public-read"
    sign("PUT", path, headers, body, timestamp)
    req = urllib.request.Request(url, data=body, headers=headers, method="PUT")
    try:
        with urllib.request.urlopen(req) as resp:
            print(f"  Uploaded: HTTP {resp.status}")
    except urllib.error.HTTPError as e:
        print(f"  Upload failed: HTTP {e.code} {e.read().decode()}")
        sys.exit(1)

    print(f"  Download URL: {ENDPOINT}{path}")
    print(f"{ENDPOINT}{path}")

if __name__ == "__main__":
    main()
