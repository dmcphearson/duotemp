# duotemp

## Build
- Compile check (no signing): `xcodebuild -project Duotemp.xcodeproj -scheme Duotemp -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
- WeatherKit, the App Group and widget location only work in a signed build on a device.
- Screenshots (debug builds): launch with `-showsSampleSkies YES`, `-openLocation sample.<id>` to open a place, and `-scrollToBottom YES` to start at the tiles. App Store size is the 6.9" iPhone 18 Pro Max simulator (1320x2868); set `xcrun simctl status_bar <id> override --time 9:41` first.

## Gotchas
- The Xcode project is hand-written with folder-synchronized groups: new files in `Duotemp/`, `DuotempWidgets/` or `Shared/` join their targets automatically. `Shared/` is in both the app and the widget extension. Each target's `Info.plist` is excluded from membership by an exception set.
- `Config/Base.xcconfig` holds the bundle prefix, team and `MET_BASE_URL`; `//` in xcconfig starts a comment, so URLs are written `https:/$()/…`.
- The app group ID is derived from the bundle ID in `SharedStore.appGroupID`; keep the widget bundle ID as `<app ID>.widgets`.
- Swift 6 language mode. MapKit and CoreLocation delegates need explicit isolation handling (see `PlaceSearch`, `OneShotLocation`).
- MET Norway terms: keep the User-Agent, the shared URLCache, coordinates at 2 decimals, and the fetch time visible in the app.
- Logs use the `[duotemp]` prefix.
