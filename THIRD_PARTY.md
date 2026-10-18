# Third-party services, frameworks and assets

duoTemp Weather has no third-party code packages: no Swift packages, CocoaPods or vendored libraries. Everything outside the app's own MIT-licensed code is listed below.

## Data services

| Service | Licence or terms | Used for |
|---|---|---|
| [MET Norway Locationforecast 2.0](https://api.met.no/weatherapi/locationforecast/2.0/documentation) | [CC BY 4.0 and NLOD 2.0](https://api.met.no/doc/License); [terms of service](https://api.met.no/doc/TermsOfService) | Default forecast: temperature, feels-like, conditions, hourly and daily forecast, rain amounts, wind, humidity, dew point, pressure, clear-sky UV, cloud cover. |
| [MET Norway Sunrise 3.0](https://api.met.no/weatherapi/sunrise/3.0/documentation) | Same as above | Sunrise and sunset times on the detail screen. |
| [Apple WeatherKit](https://developer.apple.com/weatherkit/) | [Apple Developer Program License Agreement](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/); 500,000 calls a month included with membership | The alternative forecast source, and on the detail screen it fills what MET lacks: chance of rain, wind gusts, visibility, and sun times if MET's Sunrise call fails. |
| [GFZ Potsdam Kp forecast](https://isdc.gfz-potsdam.de/kp-index-forecast/) | [CC BY 4.0](https://kp.gfz.de/en/), credit GFZ German Research Centre for Geosciences; provided as-is | Northern lights card: 3-day Kp ensemble forecast, fetched only for places far enough north or south to see aurora. |
| [NOAA SWPC planetary K-index forecast](https://www.swpc.noaa.gov/products/planetary-k-index) | US government work, public domain | Northern lights card fallback when GFZ is unavailable. |
| [Apple Maps search](https://developer.apple.com/documentation/mapkit/mklocalsearchcompleter) (MapKit) | Apple SDK and Program terms | Place search when adding a location. Typed text goes to Apple. |
| [Apple reverse geocoding](https://developer.apple.com/documentation/corelocation/clgeocoder) (Core Location) | Apple SDK and Program terms | Turns the current location's coordinates into a place name and time zone. |

**MET Norway.** CC BY 4.0 allows commercial use and adaptation with credit. The app credits "MET Norway" in the sources footer, links the licence, shows the fetch time, and follows the terms of service: an identifying User-Agent, cached responses that honour `Expires` and `If-Modified-Since`, and coordinates rounded to two decimals. MET asks apps with many users to call through their own proxy, which is planned before release.

**WeatherKit.** Wherever Apple data is shown, Apple requires its Apple Weather mark and a link to its legal attribution page; the app shows both in the sources footer. Weather alerts, if ever added, must link to Apple's alert page and must not be altered. Whether Apple allows its data to be shown beside another provider's, as the detail screen does, is not settled in the public attribution guidance and needs a check of the licence agreement's WeatherKit section before App Store submission.

## Apple frameworks

All are part of the iOS SDK, used under the [Xcode and Apple SDKs Agreement](https://www.apple.com/legal/sla/docs/xcode.pdf).

| Framework | Used for |
|---|---|
| [SwiftUI](https://developer.apple.com/documentation/swiftui) | All app and widget interface, including the drawn skies (`Canvas`, `TimelineView`). |
| [WidgetKit](https://developer.apple.com/documentation/widgetkit) | Home Screen and Lock Screen widgets and their refresh schedule. |
| [App Intents](https://developer.apple.com/documentation/appintents) | The widget's location picker. |
| [Core Location](https://developer.apple.com/documentation/corelocation) | Current location for the app and widgets, and reverse geocoding. |
| [MapKit](https://developer.apple.com/documentation/mapkit) | Place search. |
| [WeatherKit](https://developer.apple.com/documentation/weatherkit) | The client for Apple's weather service and its attribution assets. |
| [Foundation](https://developer.apple.com/documentation/foundation), [Observation](https://developer.apple.com/documentation/observation), [OSLog](https://developer.apple.com/documentation/os/logging) | Networking and caching, app state, logging. |

## Assets

| Asset | Terms | Used for |
|---|---|---|
| [SF Symbols](https://developer.apple.com/sf-symbols/) | System-provided images under the Xcode and Apple SDKs Agreement. They may not be used, nor lookalikes, in app icons, logos or any trademark use. | Weather condition icons and interface icons. The app icon must be original artwork. |
| San Francisco system font | Same agreement; used as the system font only. | All text. |
| [Outfit](https://fonts.google.com/specimen/Outfit) by Rodrigo Fuenzalida | [SIL Open Font License 1.1](https://openfontlicense.org) | The logo's wordmark, outlined into the brand SVGs. Not used in the app. |

## Published methods implemented in the app's own code

No code is copied; these are public formulas.

| Method | Source | Used for |
|---|---|---|
| NOAA low-precision solar position equations | [NOAA Global Monitoring Laboratory](https://gml.noaa.gov/grad/solcalc/solareqns.PDF), US government work | Sun elevation and day progress for the sky colours, sun position and day or night. |
| Mean synodic month from a reference new moon | Standard astronomy | Moon phase. |
| Geomagnetic latitude from the IGRF-14 dipole | [IAGA IGRF](https://www.ncei.noaa.gov/products/international-geomagnetic-reference-field) coefficients | Kp each place needs for aurora on its horizon. |
| SplitMix64 | [Sebastiano Vigna](https://prng.di.unimi.it/splitmix64.c), public domain | Repeatable placement of stars, clouds and splashes. |

## Planned, not yet in the app

| Service | Terms | Planned use |
|---|---|---|
| [RainViewer](https://www.rainviewer.com/api.html) | [Terms](https://www.rainviewer.com/terms.html): free API meant for personal, educational and small community use, with "Weather data by RainViewer" credit required; commercial or high-volume use needs an agreement. Reported tile limit of zoom 7. | Precipitation map. Confirm the terms fit a free App Store app before shipping it. |
| [Cloudflare Workers](https://developers.cloudflare.com/workers/) | Cloudflare terms; free plan | Caching proxy in front of MET Norway, as MET's terms ask. |
