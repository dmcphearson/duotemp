# duoTemp brand

The icon is a degree ring on the horizon: warm sun above, its reflection drawn as fading ripple lines below. The logo pairs it with "duoTemp" (Outfit Light and SemiBold, outlined) and "WEATHER" spaced out beneath.

| Colour | Hex | Use |
|---|---|---|
| Navy | `#12202B` | Backgrounds, logo text on light |
| Cream | `#F4F1EA` | Logo text on dark |
| Amber | `#F2B84B` | Sun, accent, WEATHER on dark |
| Deep amber | `#9A6A12` | WEATHER on light |
| Sky blue | `#8FC3E8` | Reflection |

- `svg/`: icon in light, dark and tinted (square, for the App Store) and a rounded preview. Lockups come two ways: `duotemp-lockup-dark` and `-light` sit on a navy or cream panel, ready to use as they are; `-on-dark` and `-on-light` are transparent, for placing on your own background. `duotemp-wordmark-on-dark` and `-on-light` are the words alone, for places that already show the icon, such as the app's navigation bar. Text is outlined, so no font is needed.
- `png/`: 1024 px icons, a 512 px rounded icon and all four lockups at 3x.
- The app icon is `Duotemp/AppIcon.icon`, an Icon Composer file: background, reflection and sun as separate layers, so iOS adds its glass, depth and tinting. Its dark appearance uses a dusk palette between the light and dark icons, since the system darkens it further.

Regenerate the SVGs and the app icon's layers with `python3 Brand/build_brand.py Brand/svg` (needs fontTools; Outfit is in `fonts/`, SIL OFL). Open `AppIcon.icon` in Icon Composer to adjust its glass settings; quit it before regenerating, or it may save its copy over the new layers. PNGs are rendered from the SVGs with headless Chrome.

These files are © David McPhearson, all rights reserved, and are not covered by the repository's Apache License (see the main README). The Outfit font keeps its own SIL Open Font License.
