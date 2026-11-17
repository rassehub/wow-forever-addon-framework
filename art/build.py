#!/usr/bin/env python3
"""ForeverKit's own art, drawn as code: python3 art/build.py

Writes framework/ForeverKit/Media/Icons/*.png (64x64 white glyphs on transparent: themes tint
them) and Media/Frames/*.png (64x64 nine-slice sources: corners 16 px, see FRAMES). Needs pycairo
(a dev-only dependency; the PNGs are committed, nothing at runtime needs it). The output is
deterministic, so re-running without changes leaves git clean.
"""
import math
from pathlib import Path

import cairo

OUT = Path(__file__).resolve().parent.parent / "framework" / "ForeverKit" / "Media"
S = 64          # canvas
W = 5.5         # icon stroke width (on 64): about 1.3 UI px at 16 px icons
TAU = math.tau

ICONS = {}


def icon(fn):
    ICONS[fn.__name__.replace("_", "-")] = fn
    return fn


def canvas():
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, S, S)
    c = cairo.Context(surf)
    c.set_source_rgba(1, 1, 1, 1)
    c.set_line_width(W)
    c.set_line_cap(cairo.LINE_CAP_ROUND)
    c.set_line_join(cairo.LINE_JOIN_ROUND)
    return surf, c


def poly(c, pts, close=False):
    c.move_to(*pts[0])
    for p in pts[1:]:
        c.line_to(*p)
    if close:
        c.close_path()


def rrect(c, x, y, w, h, r):
    c.new_sub_path()
    c.arc(x + w - r, y + r, r, -TAU / 4, 0)
    c.arc(x + w - r, y + h - r, r, 0, TAU / 4)
    c.arc(x + r, y + h - r, r, TAU / 4, TAU / 2)
    c.arc(x + r, y + r, r, TAU / 2, 3 * TAU / 4)
    c.close_path()


def star_points(cx, cy, ro, ri, n=5, rot=-TAU / 4):
    return [(cx + (ro if i % 2 == 0 else ri) * math.cos(rot + i * TAU / (2 * n)),
             cy + (ro if i % 2 == 0 else ri) * math.sin(rot + i * TAU / (2 * n))) for i in range(2 * n)]


# --- navigation and actions ---------------------------------------------------------------
@icon
def close(c): poly(c, [(16, 16), (48, 48)]); poly(c, [(48, 16), (16, 48)]); c.stroke()
@icon
def check(c): poly(c, [(14, 33), (27, 46), (51, 19)]); c.stroke()
@icon
def plus(c): poly(c, [(32, 13), (32, 51)]); poly(c, [(13, 32), (51, 32)]); c.stroke()
@icon
def minus(c): poly(c, [(13, 32), (51, 32)]); c.stroke()
@icon
def arrow_right(c): poly(c, [(24, 14), (42, 32), (24, 50)]); c.stroke()
@icon
def arrow_left(c): poly(c, [(40, 14), (22, 32), (40, 50)]); c.stroke()
@icon
def arrow_down(c): poly(c, [(14, 24), (32, 42), (50, 24)]); c.stroke()
@icon
def arrow_up(c): poly(c, [(14, 40), (32, 22), (50, 40)]); c.stroke()
@icon
def back(c): poly(c, [(50, 32), (14, 32)]); poly(c, [(28, 18), (14, 32), (28, 46)]); c.stroke()
@icon
def forward(c): poly(c, [(14, 32), (50, 32)]); poly(c, [(36, 18), (50, 32), (36, 46)]); c.stroke()
@icon
def menu(c):
    for y in (18, 32, 46):
        poly(c, [(14, y), (50, y)])
    c.stroke()
@icon
def dots(c):
    for x in (16, 32, 48):
        c.arc(x, 32, 4.5, 0, TAU); c.fill()
@icon
def grip(c):  # window resize corner
    for d in (0, 12, 24):
        poly(c, [(50 - d, 52), (52, 50 - d)])
    c.stroke()
@icon
def handle(c):  # drag handle
    for x in (24, 40):
        for y in (18, 32, 46):
            c.arc(x, y, 4, 0, TAU); c.fill()
@icon
def refresh(c):
    a0, a1 = TAU * 0.12, TAU * 0.86          # gap at the upper right; travels clockwise
    c.arc(32, 32, 17, a0, a1); c.stroke()
    px, py = 32 + 17 * math.cos(a1), 32 + 17 * math.sin(a1)
    tx, ty = -math.sin(a1), math.cos(a1)      # direction of travel at the end
    tip = (px + tx * 6, py + ty * 6)
    for side in (1, -1):                      # two wings 40 degrees off the reversed tangent
        ang = math.atan2(-ty, -tx) + side * math.radians(40)
        poly(c, [tip, (tip[0] + 11 * math.cos(ang), tip[1] + 11 * math.sin(ang))])
    c.stroke()
@icon
def search(c):
    c.arc(28, 28, 14, 0, TAU); c.stroke(); poly(c, [(38.5, 38.5), (51, 51)]); c.stroke()
@icon
def filter(c): poly(c, [(12, 15), (52, 15), (36, 34), (36, 50), (28, 46), (28, 34)], close=True); c.stroke()
@icon
def sort(c):
    for i, x2 in enumerate((50, 40, 30)):
        poly(c, [(14, 18 + i * 14), (x2, 18 + i * 14)])
    c.stroke()
@icon
def cog(c):
    teeth = 8
    for i in range(teeth):
        a = i * TAU / teeth
        c.save(); c.translate(32, 32); c.rotate(a)
        c.rectangle(-4.5, -24, 9, 9); c.fill(); c.restore()
    c.arc(32, 32, 15, 0, TAU); c.stroke()
    c.arc(32, 32, 5, 0, TAU); c.fill()
@icon
def edit(c):
    poly(c, [(15, 49), (17, 39), (41, 15), (49, 23), (25, 47)], close=True); c.stroke()
    poly(c, [(35, 21), (43, 29)]); c.stroke()
@icon
def trash(c):
    poly(c, [(13, 19), (51, 19)]); poly(c, [(26, 19), (27, 13), (37, 13), (38, 19)]); c.stroke()
    poly(c, [(18, 19), (21, 51), (43, 51), (46, 19)]); c.stroke()
    poly(c, [(28, 27), (28, 43)]); poly(c, [(36, 27), (36, 43)]); c.stroke()
@icon
def copy(c):
    rrect(c, 22, 22, 28, 28, 4); c.stroke()
    poly(c, [(14, 40), (14, 18), (18, 14), (40, 14)]); c.stroke()
@icon
def link(c):
    c.save(); c.translate(32, 32); c.rotate(-TAU / 8)
    rrect(c, -22, -7, 24, 14, 7); c.stroke(); rrect(c, -2, -7, 24, 14, 7); c.stroke(); c.restore()
@icon
def lock(c):
    rrect(c, 15, 29, 34, 23, 4); c.fill()
    c.move_to(22, 30); c.line_to(22, 22); c.arc(32, 22, 10, TAU / 2, TAU); c.line_to(42, 30); c.stroke()
@icon
def unlock(c):
    rrect(c, 15, 29, 34, 23, 4); c.fill()
    c.move_to(42, 30); c.line_to(42, 22); c.arc_negative(32, 22, 10, 0, TAU / 2); c.line_to(22, 18); c.stroke()
@icon
def eye(c):
    c.move_to(10, 32); c.curve_to(22, 14, 42, 14, 54, 32); c.curve_to(42, 50, 22, 50, 10, 32); c.stroke()
    c.arc(32, 32, 7, 0, TAU); c.fill()
@icon
def home(c):
    poly(c, [(12, 31), (32, 13), (52, 31)]); c.stroke()
    poly(c, [(18, 27), (18, 51), (46, 51), (46, 27)]); c.stroke()
    poly(c, [(28, 51), (28, 38), (36, 38), (36, 51)]); c.stroke()
@icon
def info(c):
    c.arc(32, 32, 22, 0, TAU); c.stroke()
    c.arc(32, 21, 3.5, 0, TAU); c.fill(); poly(c, [(32, 29), (32, 44)]); c.stroke()
@icon
def warning(c):
    poly(c, [(32, 11), (54, 51), (10, 51)], close=True); c.stroke()
    poly(c, [(32, 25), (32, 37)]); c.stroke(); c.arc(32, 44.5, 3.2, 0, TAU); c.fill()
@icon
def bell(c):
    c.move_to(16, 44); c.curve_to(20, 38, 18, 18, 32, 16); c.curve_to(46, 18, 44, 38, 48, 44); c.close_path(); c.stroke()
    c.arc(32, 49, 4, 0, TAU / 2); c.stroke()
@icon
def clock(c):
    c.arc(32, 32, 21, 0, TAU); c.stroke(); poly(c, [(32, 19), (32, 32), (41, 38)]); c.stroke()
@icon
def list(c):
    for y in (18, 32, 46):
        c.arc(15, y, 3.5, 0, TAU); c.fill(); poly(c, [(24, y), (51, y)]); c.stroke()
@icon
def grid(c):
    for x in (13, 35):
        for y in (13, 35):
            rrect(c, x, y, 16, 16, 3); c.fill()
@icon
def user(c):
    c.arc(32, 22, 9, 0, TAU); c.stroke()
    c.move_to(13, 52); c.curve_to(15, 36, 49, 36, 51, 52); c.stroke()
@icon
def star(c): poly(c, star_points(32, 34, 22, 9.5), close=True); c.stroke()
@icon
def star_filled(c): poly(c, star_points(32, 34, 22, 9.5), close=True); c.fill()
@icon
def flag(c):
    poly(c, [(17, 54), (17, 11)]); c.stroke()
    poly(c, [(17, 13), (48, 13), (40, 23), (48, 33), (17, 33)], close=True); c.fill()

# --- world and game -----------------------------------------------------------------------
@icon
def pin(c):
    c.move_to(32, 55); c.curve_to(18, 38, 14, 30, 14, 25); c.arc(32, 25, 18, TAU / 2, TAU)
    c.curve_to(50, 30, 46, 38, 32, 55); c.close_path(); c.stroke()
    c.arc(32, 25, 6, 0, TAU); c.fill()
@icon
def map(c):
    poly(c, [(10, 16), (24, 11), (40, 17), (54, 12), (54, 48), (40, 53), (24, 47), (10, 52)], close=True); c.stroke()
    poly(c, [(24, 11), (24, 47)]); poly(c, [(40, 17), (40, 53)]); c.stroke()
@icon
def compass(c):
    c.arc(32, 32, 22, 0, TAU); c.stroke()
    poly(c, [(32, 15), (38, 32), (32, 49), (26, 32)], close=True); c.fill()
@icon
def book(c):
    poly(c, [(32, 18), (32, 52)]); c.stroke()
    c.move_to(32, 18); c.curve_to(24, 12, 16, 12, 9, 15); c.line_to(9, 49); c.curve_to(16, 46, 24, 46, 32, 52); c.stroke()
    c.move_to(32, 18); c.curve_to(40, 12, 48, 12, 55, 15); c.line_to(55, 49); c.curve_to(48, 46, 40, 46, 32, 52); c.stroke()
@icon
def scroll(c):
    rrect(c, 16, 12, 32, 40, 4); c.stroke()
    for y in (23, 32, 41):
        poly(c, [(24, y), (40, y)])
    c.stroke()
@icon
def quest(c):  # quest available
    rrect(c, 27, 9, 10, 32, 5); c.fill(); c.arc(32, 51, 5.5, 0, TAU); c.fill()
@icon
def quest_turnin(c):
    c.set_line_width(8)
    c.arc(32, 22, 11, TAU / 2, TAU * 1.08); c.line_to(32, 37); c.stroke()
    c.arc(32, 51, 5.5, 0, TAU); c.fill()
@icon
def bag(c):
    c.move_to(14, 26); c.line_to(50, 26); c.line_to(46, 54); c.line_to(18, 54); c.close_path(); c.stroke()
    c.arc(32, 26, 9, TAU / 2, TAU); c.stroke()
@icon
def coin(c):
    c.arc(32, 32, 21, 0, TAU); c.stroke(); c.arc(32, 32, 12, 0, TAU); c.fill()
@icon
def chest(c):
    rrect(c, 11, 26, 42, 26, 3); c.stroke()
    c.move_to(11, 30); c.curve_to(11, 12, 53, 12, 53, 30); c.stroke()
    rrect(c, 28, 30, 8, 10, 2); c.fill()
@icon
def sword(c):
    poly(c, [(53, 11), (51, 21), (27, 45), (19, 37), (43, 13)], close=True); c.fill()   # blade
    c.set_line_width(7); poly(c, [(15, 33), (31, 49)]); c.stroke()                       # guard
    c.set_line_width(6); poly(c, [(21, 43), (12, 52)]); c.stroke()                       # grip
@icon
def shield(c):
    c.move_to(32, 10); c.line_to(51, 17); c.curve_to(51, 36, 44, 47, 32, 55); c.curve_to(20, 47, 13, 36, 13, 17)
    c.close_path(); c.stroke(); poly(c, [(32, 18), (32, 46)]); c.stroke()
@icon
def skull(c):
    c.arc(32, 28, 18, TAU / 2 * 0.95, TAU * 1.025); c.line_to(44, 52); c.line_to(20, 52); c.close_path(); c.stroke()
    c.arc(25, 29, 5, 0, TAU); c.fill(); c.arc(39, 29, 5, 0, TAU); c.fill()
@icon
def herb(c):
    c.move_to(32, 54); c.curve_to(32, 40, 28, 30, 18, 22); c.stroke()
    c.move_to(30, 34); c.curve_to(14, 36, 8, 22, 10, 12); c.curve_to(22, 12, 30, 20, 30, 34); c.fill()
    c.move_to(33, 40); c.curve_to(48, 40, 56, 28, 54, 18); c.curve_to(42, 18, 34, 26, 33, 40); c.fill()
@icon
def ore(c):
    poly(c, [(12, 44), (20, 22), (36, 14), (52, 26), (50, 46), (32, 52)], close=True); c.stroke()
    poly(c, [(20, 22), (32, 32), (36, 14)]); poly(c, [(32, 32), (50, 46)]); poly(c, [(32, 32), (12, 44)]); c.stroke()
@icon
def flame(c):
    c.move_to(32, 54); c.curve_to(14, 52, 12, 34, 24, 22); c.curve_to(24, 30, 28, 32, 30, 32)
    c.curve_to(28, 22, 32, 14, 40, 9); c.curve_to(38, 20, 52, 28, 50, 42); c.curve_to(48, 50, 40, 54, 32, 54); c.fill()
@icon
def dungeon(c):  # portal arch
    c.move_to(14, 54); c.line_to(14, 30); c.arc(32, 30, 18, TAU / 2, TAU); c.line_to(50, 54); c.stroke()
    c.move_to(23, 54); c.line_to(23, 32); c.arc(32, 32, 9, TAU / 2, TAU); c.line_to(41, 54); c.fill()


# --- nine-slice frames ----------------------------------------------------------------------
# Each is a 64x64 image: 16 px corners, edges stretch, centre transparent (themes fill it).
FRAMES = {}


def frame(fn):
    FRAMES[fn.__name__.replace("_", "-")] = fn
    return fn


def grad(c, y0, y1, stops):
    g = cairo.LinearGradient(0, y0, 0, y1)
    for off, rgba in stops:
        g.add_color_stop_rgba(off, *rgba)
    return g


@frame
def metal(c):
    """Thin bevelled metal edge with a dark inner line: the modern Settings-panel look."""
    rrect(c, 1.5, 1.5, 61, 61, 6); c.set_line_width(3)
    c.set_source(grad(c, 0, 64, [(0, (0.78, 0.78, 0.8, 1)), (0.5, (0.42, 0.42, 0.45, 1)), (1, (0.62, 0.62, 0.65, 1))])); c.stroke()
    rrect(c, 4, 4, 56, 56, 4); c.set_line_width(1.5); c.set_source_rgba(0, 0, 0, 0.85); c.stroke()


@frame
def thin(c):
    """One fine rounded line with a faint dark outline: the modern thin border (white, tintable)."""
    rrect(c, 1.5, 1.5, 61, 61, 4); c.set_line_width(2.5); c.set_source_rgba(0, 0, 0, 0.5); c.stroke()
    rrect(c, 1.5, 1.5, 61, 61, 4); c.set_line_width(1.2); c.set_source_rgba(1, 1, 1, 1); c.stroke()


@frame
def soft(c):
    """Rounded hairline with a soft outer shadow (midnight)."""
    for i in range(6, 0, -1):
        rrect(c, 6 - i, 6 - i, 52 + 2 * i, 52 + 2 * i, 10 + i); c.set_source_rgba(0, 0, 0, 0.07); c.set_line_width(2); c.stroke()
    rrect(c, 6.5, 6.5, 51, 51, 10); c.set_line_width(1.2); c.set_source_rgba(1, 1, 1, 0.55); c.stroke()


@frame
def double(c):
    """Two fine lines with a gap: ornamental, tintable (white)."""
    rrect(c, 2, 2, 60, 60, 3); c.set_line_width(2); c.set_source_rgba(1, 1, 1, 1); c.stroke()
    rrect(c, 6, 6, 52, 52, 2); c.set_line_width(1); c.set_source_rgba(1, 1, 1, 0.7); c.stroke()
    for x, y in ((2, 2), (62, 2), (2, 62), (62, 62)):
        c.arc(x, y, 3.5, 0, TAU); c.fill()


@frame
def button(c):
    """Rounded button body, light top to darker bottom, white so states tint it."""
    rrect(c, 1, 1, 62, 62, 7)
    c.set_source(grad(c, 0, 64, [(0, (1, 1, 1, 1)), (0.55, (0.86, 0.86, 0.86, 1)), (1, (0.7, 0.7, 0.7, 1))])); c.fill_preserve()
    c.set_line_width(1.5); c.set_source_rgba(0, 0, 0, 0.6); c.stroke()
    rrect(c, 3, 3, 58, 30, 5); c.set_source_rgba(1, 1, 1, 0.25); c.fill()


@frame
def pill(c):
    """Fully rounded (toggle tracks, tags)."""
    rrect(c, 1, 1, 62, 62, 15.5); c.set_source_rgba(1, 1, 1, 1); c.fill()


@frame
def glow(c):
    """Outer glow ring for highlights: additive, tinted by the accent colour."""
    for i in range(14, 0, -1):
        rrect(c, 16 - i, 16 - i, 32 + 2 * i, 32 + 2 * i, 6 + i)
        c.set_source_rgba(1, 1, 1, 0.045); c.set_line_width(2.2); c.stroke()


def main():
    (OUT / "Icons").mkdir(parents=True, exist_ok=True)
    (OUT / "Frames").mkdir(parents=True, exist_ok=True)
    for name, fn in ICONS.items():
        surf, c = canvas()
        fn(c)
        surf.write_to_png(str(OUT / "Icons" / f"{name}.png"))
    for name, fn in FRAMES.items():
        surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, S, S)
        c = cairo.Context(surf)
        c.set_source_rgba(1, 1, 1, 1)
        fn(c)
        surf.write_to_png(str(OUT / "Frames" / f"{name}.png"))
    # the list of names, so the library can tell a media icon from a typo
    names = ", ".join(f'["{n}"] = true' for n in sorted(ICONS))
    (OUT / "Icons.lua").write_text(
        "-- Generated by art/build.py: the icons in Media/Icons. Do not edit.\n"
        "local _, ns = ...\n"
        f"ns.FK.mediaIcons = {{ {names} }}\n")
    # contact sheet for looking at the set (not shipped)
    sheet_cols = 10
    rows = math.ceil(len(ICONS) / sheet_cols)
    sheet = cairo.ImageSurface(cairo.FORMAT_ARGB32, sheet_cols * 80, rows * 96 + 100)
    c = cairo.Context(sheet)
    c.set_source_rgb(0.12, 0.12, 0.14); c.paint()
    c.select_font_face("Sans"); c.set_font_size(9)
    for i, name in enumerate(ICONS):
        x, y = (i % sheet_cols) * 80 + 8, (i // sheet_cols) * 96 + 8
        img = cairo.ImageSurface.create_from_png(str(OUT / "Icons" / f"{name}.png"))
        c.set_source_surface(img, x, y); c.paint()
        c.set_source_rgb(0.8, 0.8, 0.8); c.move_to(x, y + 80); c.show_text(name)
    for i, name in enumerate(FRAMES):
        img = cairo.ImageSurface.create_from_png(str(OUT / "Frames" / f"{name}.png"))
        c.set_source_surface(img, i * 80 + 8, rows * 96 + 10); c.paint()
    out = Path(__file__).resolve().parent.parent / ".preview" / "art-sheet.png"
    out.parent.mkdir(exist_ok=True)
    sheet.write_to_png(str(out))
    print(f"{len(ICONS)} icons, {len(FRAMES)} frames -> {OUT}; contact sheet {out}")


if __name__ == "__main__":
    main()
