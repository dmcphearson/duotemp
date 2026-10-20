# duotemp

## Build
- Compile check (no signing): `xcodebuild -project Duotemp.xcodeproj -scheme Duotemp -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
- WeatherKit, the App Group and widget location only work in a signed build on a device.
- To install on a simulator, build without `CODE_SIGNING_ALLOWED=NO`: an unsigned build has no App Group entitlement, so the widget renders blank.
- Proxy (`proxy/`, a Cloudflare Worker at api.trough.dev for MET and the aurora Kp files): `node --test proxy/test/proxy.test.mjs`. Merging to main deploys it via `.github/workflows/proxy.yml` (repo secret `CLOUDFLARE_API_TOKEN`, variable `CLOUDFLARE_ACCOUNT_ID`). Plain ES modules, no npm dependencies.
- Screenshots (debug builds): launch with `-showsSampleSkies YES`, `-screenshotCities YES` for the list of real city names with chosen skies (`SampleSkies.cities`), `-openLocation sample.<id>` to open a place, and `-scrollAnchor 0.6` to start part way down (0 top, 1 bottom). App Store size is the 6.9" iPhone 18 Pro Max simulator (1320x2868); set `xcrun simctl status_bar <id> override --time 9:41` first, and capture with `xcrun simctl io <id> screenshot --mask=ignored` so the Dynamic Island never shows.

## Gotchas
- The Xcode project is hand-written with folder-synchronized groups: new files in `Duotemp/`, `DuotempWidgets/` or `Shared/` join their targets automatically. `Shared/` is in both the app and the widget extension. Each target's `Info.plist` is excluded from membership by an exception set.
- `Config/Base.xcconfig` holds the bundle prefix and team, and points MET and the aurora files at the sources directly. David's builds set `PROXY_BASE_URL` and `MET_BASE_URL` to the proxy in the gitignored `Config/Local.xcconfig`; archive only with that file present. `//` in xcconfig starts a comment, so URLs are written `https:/$()/…`.
- The app group ID is derived from the bundle ID in `SharedStore.appGroupID`; keep the widget bundle ID as `<app ID>.widgets`.
- Swift 6 language mode. MapKit and CoreLocation delegates need explicit isolation handling (see `PlaceSearch`, `OneShotLocation`).
- MET Norway terms: App Store builds go through the proxy, which sends MET a User-Agent with the api@trough.dev contact and caches until `Expires`. Direct calls send `UserAgent.value` (USER_AGENT_NAME and USER_AGENT_CONTACT, set in Local.xcconfig for David's builds; empty, the bundle ID). Keep the shared URLCache, coordinates at 2 decimals, and the fetch time visible in the app.
- Logs use the `[duotemp]` prefix.
