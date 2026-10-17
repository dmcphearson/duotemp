"""Build duoTemp brand SVGs: the ring-on-the-horizon icon and the logo lockups, wordmark outlined from Outfit."""
import math
import sys
from pathlib import Path

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

HERE = Path(__file__).parent
FONT = HERE / "fonts/Outfit-Variable.ttf"
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE / "svg"

# Icon palettes: sky gradient stops (offset %, colour), sun, reflection, glow strength.
VARIANTS = {
    "light": {
        "sky": [(0, "#2A3468"), (34, "#6E4C80"), (52, "#C8657A"), (62, "#F2A65A"), (62, "#10202C"), (100, "#1F3546")],
        "warm": "#F2B84B", "cool": "#8FC3E8", "glow": 0.5,
    },
    "dark": {
        "sky": [(0, "#121733"), (34, "#3A2846"), (52, "#7A3E52"), (62, "#B8704A"), (62, "#05080B"), (100, "#0D141B")],
        "warm": "#F6C463", "cool": "#9DCDF0", "glow": 0.42,
    },
    "tinted": {
        "sky": [(0, "#0C0C0C"), (45, "#1A1A1A"), (62, "#2C2C2C"), (62, "#000000"), (100, "#070707")],
        "warm": "#E6E6E6", "cool": "#8E8E8E", "glow": 0.22,
    },
}

# Icon geometry in a 100-unit square: the ring sits on the horizon at y 62.
CX, CY, OUTER, INNER = 50, 62, 25, 15.5
LINE, LINE_CENTRES = 3, [63.6, 68.6, 73.6, 78.6, 83.6]
LINE_FADES = [0.95, 0.85, 0.75, 0.64, 0.54]
BREAK = 3.75  # half the break in a line just below the hole: 7.5% of the icon's width
CORNER = 22.37  # iOS-style corner radius for previews; the App Store icon itself is square

NAVY, CREAM, AMBER, DEEP_AMBER = "#12202B", "#F4F1EA", "#F2B84B", "#9A6A12"


def ripple_lines():
    """The reflection: thin round-ended lines that trace the ring's lower half and fade going down."""
    lines = []
    for y, opacity in zip(LINE_CENTRES, LINE_FADES):
        dy = y - CY
        out = math.sqrt(max(OUTER**2 - dy**2, 0)) - LINE / 2
        if dy < INNER + 2:
            inner = max(math.sqrt(max(INNER**2 - dy**2, 0)), BREAK) + LINE / 2
            lines += [(CX + inner, CX + out, y, opacity), (CX - out, CX - inner, y, opacity)]
        else:
            lines.append((CX - out, CX + out, y, opacity))
    return lines


def icon_body(variant, prefix):
    v = VARIANTS[variant]
    stops = "".join(f'<stop offset="{o}%" stop-color="{c}"/>' for o, c in v["sky"])
    lines = "".join(
        f'<path d="M{a:.2f} {y}H{b:.2f}" stroke="{v["cool"]}" stroke-opacity="{op}"/>' for a, b, y, op in ripple_lines()
    )
    warm = v["warm"]
    return f"""<defs>
<linearGradient id="{prefix}sky" x1="0" y1="0" x2="0" y2="1">{stops}</linearGradient>
<radialGradient id="{prefix}glow" cx="50" cy="62" r="44" gradientTransform="matrix(1 0 0 0.409 0 36.6)" gradientUnits="userSpaceOnUse">
<stop offset="0" stop-color="{warm}" stop-opacity="{v["glow"]}"/><stop offset="1" stop-color="{warm}" stop-opacity="0"/></radialGradient>
<linearGradient id="{prefix}line" x1="8" y1="0" x2="92" y2="0" gradientUnits="userSpaceOnUse">
<stop offset="0" stop-color="{warm}" stop-opacity="0"/><stop offset="0.5" stop-color="{warm}" stop-opacity="0.55"/><stop offset="1" stop-color="{warm}" stop-opacity="0"/></linearGradient>
</defs>
<rect width="100" height="100" fill="url(#{prefix}sky)"/>
<rect x="6" y="44" width="88" height="36" fill="url(#{prefix}glow)"/>
<g fill="none" stroke-width="{LINE}" stroke-linecap="round">{lines}</g>
<rect x="8" y="61.8" width="84" height="0.6" fill="url(#{prefix}line)"/>
<path d="M{CX - OUTER} {CY}A{OUTER} {OUTER} 0 0 1 {CX + OUTER} {CY}H{CX + INNER}A{INNER} {INNER} 0 0 0 {CX - INNER} {CY}Z" fill="{warm}"/>"""


def icon_svg(variant, size=1024, rounded=False):
    clip = ""
    body = icon_body(variant, "")
    if rounded:
        clip = f'<clipPath id="corner"><rect width="100" height="100" rx="{CORNER}"/></clipPath>'
        body = f'<g clip-path="url(#corner)">{body}</g>'
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 100 100">'
        f"<title>duoTemp</title>{clip}{body}</svg>\n"
    )


class Face:
    """One weight of Outfit, with its pair kerning, for outlining text."""

    def __init__(self, weight):
        self.font = instantiateVariableFont(TTFont(FONT), {"wght": weight})
        self.glyphs = self.font.getGlyphSet()
        self.cmap = self.font.getBestCmap()
        self.upm = self.font["head"].unitsPerEm
        self.hmtx = self.font["hmtx"]
        self.kerning = self._pairs()

    def _pairs(self):
        """Pair adjustments from GPOS lookup type 2, flattened to a dict; the first value found wins."""
        pairs = {}
        if "GPOS" not in self.font:
            return pairs
        for lookup in self.font["GPOS"].table.LookupList.Lookup:
            for sub in lookup.SubTable:
                if lookup.LookupType == 9:
                    sub = sub.ExtSubTable
                if getattr(sub, "LookupType", lookup.LookupType) != 2:
                    continue
                first = sub.Coverage.glyphs
                if sub.Format == 1:
                    for left, pairset in zip(first, sub.PairSet):
                        for rec in pairset.PairValueRecord:
                            value = getattr(rec.Value1, "XAdvance", 0) or 0
                            pairs.setdefault((left, rec.SecondGlyph), value)
                elif sub.Format == 2:
                    c1, c2 = sub.ClassDef1.classDefs, sub.ClassDef2.classDefs
                    seconds = {}
                    for glyph, cls in c2.items():
                        seconds.setdefault(cls, []).append(glyph)
                    for left in first:
                        row = sub.Class1Record[c1.get(left, 0)]
                        for cls, rec in enumerate(row.Class2Record):
                            value = getattr(rec.Value1, "XAdvance", 0) or 0
                            if value and cls in seconds:
                                for right in seconds[cls]:
                                    pairs.setdefault((left, right), value)
        return pairs

    def outline(self, text, x, baseline, size, tracking=0.0):
        """Path data for `text` starting at x on the baseline, and the x where it ends."""
        scale = size / self.upm
        parts = []
        names = [self.cmap[ord(ch)] for ch in text]
        for index, name in enumerate(names):
            pen = SVGPathPen(self.glyphs)
            self.glyphs[name].draw(TransformPen(pen, (scale, 0, 0, -scale, x, baseline)))
            parts.append(pen.getCommands())
            x += self.hmtx[name][0] * scale + tracking * size
            if index + 1 < len(names):
                x += self.kerning.get((name, names[index + 1]), 0) * scale
        return " ".join(p for p in parts if p), x


def lockup_svg(text_colour, label_colour, title, background=None):
    """Icon, then duoTemp in light and semibold with WEATHER spaced out beneath. Transparent by default;
    with a background it sits centred on a padded panel, the icon lifted by a soft shadow."""
    light, semibold, medium = Face(300), Face(600), Face(500)
    icon, gap, size = 96, 24, 60
    word_x = icon + gap
    baseline = 50
    duo, x = light.outline("duo", word_x, baseline, size, -0.02)
    # The weight change leaves a gap after "duo"; close it so the name reads as one word.
    temp, end = semibold.outline("Temp", x - size * 0.03, baseline, size, -0.02)
    label, label_end = medium.outline("WEATHER", word_x + 3, baseline + 26, 15, 0.42)
    content_width = math.ceil(max(end, label_end))
    pad_x, pad_y = (64, 40) if background else (0, 0)
    width, height = content_width + pad_x * 2, icon + pad_y * 2
    panel, shadow, lift = "", "", ""
    if background:
        panel = f'<rect width="{width}" height="{height}" fill="{background}"/>'
        shadow = (
            '<filter id="lift" x="-30%" y="-30%" width="160%" height="170%">'
            '<feDropShadow dx="0" dy="4" stdDeviation="5" flood-color="#000" flood-opacity="0.35"/></filter>'
        )
        lift = ' filter="url(#lift)"'
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">'
        f"<title>{title}</title>"
        f'<defs><clipPath id="corner"><rect width="100" height="100" rx="{CORNER}"/></clipPath>{shadow}</defs>'
        f"{panel}"
        f'<g transform="translate({pad_x} {pad_y})">'
        f'<g{lift}><g transform="scale({icon / 100})" clip-path="url(#corner)">{icon_body("light", "i")}</g></g>'
        f'<path d="{duo} {temp}" fill="{text_colour}"/>'
        f'<path d="{label}" fill="{label_colour}"/>'
        "</g></svg>\n"
    )


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for variant in VARIANTS:
        (OUT / f"duotemp-icon-{variant}.svg").write_text(icon_svg(variant))
    (OUT / "duotemp-icon-rounded.svg").write_text(icon_svg("light", 512, rounded=True))
    (OUT / "duotemp-lockup-on-dark.svg").write_text(lockup_svg(CREAM, AMBER, "duoTemp Weather"))
    (OUT / "duotemp-lockup-on-light.svg").write_text(lockup_svg(NAVY, DEEP_AMBER, "duoTemp Weather"))
    (OUT / "duotemp-lockup-dark.svg").write_text(lockup_svg(CREAM, AMBER, "duoTemp Weather", background=NAVY))
    (OUT / "duotemp-lockup-light.svg").write_text(lockup_svg(NAVY, DEEP_AMBER, "duoTemp Weather", background=CREAM))
    print(f"[duotemp] Wrote brand SVGs to {OUT}")


if __name__ == "__main__":
    main()
