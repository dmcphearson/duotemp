# duoTemp brand

The icon is a degree ring on the horizon: warm sun above, its reflection drawn as fading ripple lines below. The logo pairs it with "duoTemp" (Outfit Light and SemiBold, outlined) and "WEATHER" spaced out beneath.

| Colour | Hex | Use |
|---|---|---|
| Navy | `#12202B` | Backgrounds, logo text on light |
| Cream | `#F4F1EA` | Logo text on dark |
| Amber | `#F2B84B` | Sun, accent, WEATHER on dark |
| Deep amber | `#9A6A12` | WEATHER on light |
| Sky blue | `#8FC3E8` | Reflection |

- `svg/`: icon in light, dark and tinted (square, for the App Store), a rounded preview, and the lockup for dark and light backgrounds. Text is outlined, so no font is needed.
- `png/`: 1024 px icons, a 512 px rounded icon and the lockups at 3x.
- The app's icon set (`Duotemp/Assets.xcassets/AppIcon.appiconset`) uses the 1024 px PNGs.

Regenerate the SVGs with `python3 Brand/build_brand.py Brand/svg` (needs fontTools; Outfit is in `fonts/`, SIL OFL). PNGs are rendered from the SVGs with headless Chrome.
