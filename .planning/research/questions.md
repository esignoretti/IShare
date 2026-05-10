# Open Research Questions

## aws-sdk-swift Compatibility
- Does aws-sdk-swift support S3-compatible endpoints (Cubbit DS3) or is it locked to AWS?
- Can we configure custom endpoint URL, path-style vs virtual-hosted addressing?

## Finder Sync Extension Limitations
- Can a Finder Sync extension trigger an upload and show progress, or is it limited to contextual menu actions?
- What are the sandbox constraints for accessing files from a Finder Sync extension?

## Lifecycle Rule via SDK
- Does aws-sdk-swift support `putBucketLifecycleConfiguration` for non-AWS S3-compatible endpoints?
- Can lifecycle rules be set on bucket creation, or must they be applied after?

## Menu Bar vs Status Item
- Best practices for SwiftUI menu bar app with persistent state (file list)
- How to handle app termination vs. staying alive in menu bar only
