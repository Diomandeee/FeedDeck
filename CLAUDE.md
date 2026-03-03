# FeedDeck

## Overview
iOS app — FeedDeck

## Build
- Uses xcodegen: `xcodegen generate` to regenerate .xcodeproj
- Bundle ID: `com.openclaw.feeddeck`
- Team: `8643C988C4`
- Min iOS: 17.0, Swift 6

## Deploy
- Archive: `xcodebuild archive -scheme FeedDeck ...`
- Export: Uses `ExportOptions.plist` (destination=export, NOT upload)
- TestFlight: Tag with `v*` to trigger GitHub Actions upload

## Gotchas
- Always use `-skipMacroValidation -skipPackagePluginValidation` for TCA apps
- iPad orientations: ALL 4 required in Info.plist
- CFBundleIconName must be set or TestFlight upload 409s
