"""The fixtures you work at: the pizza counter and its rail, the side counter with the cutting board, the pass, the
bin, the sheeter, the ovens, the prep station and the logs for a wood oven. Room coordinates unless a docstring
says the model is a prop (then it is built round its own origin, base at y = 0)."""
from lib import *
from common import *


def _feet(xs, zs, y0=0.0, h=0.06):
    for x in xs:
        for z in zs:
            cyl(0.022, h, (x, y0 + h / 2, z), steel_dark(), seg=10, name="foot")


def _door_front(cx, cy, w, h, zf, handle_y):
    """a stainless door on a counter front facing the player (+Z)"""
    box((w, h, 0.02), (cx, cy, zf), steel(), bevel=0.006, name="door")
    box((w * 0.62, 0.022, 0.028), (cx, handle_y, zf + 0.022), chrome(), bevel=0.008, name="handle")


@model("counter")
def counter():
    s = steel()
    # the refrigerated base: body, feet, kick plate, two doors
    box((1.6, 0.82, 0.7), (0, 0.47, -0.75), s, bevel=0.01, name="body")
    _feet((-0.74, 0.74), (-1.04, -0.46))
    box((1.56, 0.06, 0.02), (0, 0.09, -0.395), steel_dark(), name="kick")
    for x in (-0.4, 0.4):
        _door_front(x, 0.5, 0.76, 0.66, -0.392, 0.79)
    box((0.16, 0.05, 0.01), (0.62, 0.18, -0.383), black(), bevel=0.004, name="display")
    box((0.08, 0.025, 0.004), (0.6, 0.18, -0.377), mat("led_red", "#ff4a2a", emit="#ff3a1a", emit_k=2.5), name="display_led")
    # the marble top, deep enough for the bench and the sheeter
    box((1.62, 0.04, 0.8), (0, 0.9, -0.72), marble(), bevel=0.006, name="marble")
    # the chilled rail of gastro pans along the back
    box((1.62, 0.08, 0.02), (0, 0.96, -0.88), s, bevel=0.004, name="rail_front")
    box((1.62, 0.08, 0.02), (0, 0.96, -1.12), s, bevel=0.004, name="rail_back")
    for x in (-0.8, 0.8):
        box((0.02, 0.08, 0.26), (x, 0.96, -1.0), s, bevel=0.004, name="rail_end")
    box((1.6, 0.01, 0.24), (0, 0.926, -1.0), mat("rail_cold", "#7f8c93", rough=0.3, metal=0.6), name="rail_well")
    # the sneeze guard over the rail
    box((1.56, 0.006, 0.22), (0, 1.13, -1.0), glass(), rot=(25, 0, 0), name="guard")
    for x in (-0.79, 0.0, 0.79):
        tube([(x, 0.99, -1.1), (x, 1.17, -1.06), (x, 1.13, -0.92)], 0.008, chrome(), name="guard_post")
    tube([(-0.8, 1.13 + 0.047, -1.1), (0.8, 1.13 + 0.047, -1.1)], 0.007, chrome(), name="guard_bar")
    # the ticket rail on the wall above the hatch
    alu = mat("alu", "#c4c9cc", rough=0.3, metal=0.7)
    box((1.72, 0.032, 0.036), (0, 1.96, -1.077), alu, bevel=0.006, name="ticket_rail")
    box((1.72, 0.006, 0.004), (0, 1.951, -1.058), black(), name="ticket_slot")
    for x in (-0.87, 0.87):
        box((0.03, 0.06, 0.06), (x, 1.96, -1.09), alu, bevel=0.005, name="ticket_bracket")


@model("counter.side")
def side():
    s = steel()
    box((0.82, 0.82, 0.84), (1.22, 0.47, -0.70), s, bevel=0.01, name="body")
    _feet((0.86, 1.58), (-1.06, -0.34))
    box((0.84, 0.04, 0.86), (1.22, 0.9, -0.70), s, bevel=0.006, name="top")
    # two dough drawers on the front
    for k, y in enumerate((0.69, 0.33)):
        box((0.76, 0.32, 0.02), (1.22, y, -0.272), s, bevel=0.006, name="drawer")
        box((0.46, 0.022, 0.028), (1.22, y + 0.12, -0.25), chrome(), bevel=0.008, name="drawer_handle")
    box((0.78, 0.06, 0.02), (1.22, 0.09, -0.275), steel_dark(), name="kick")
    # the wooden cutting board (the board you slice on sits on it in service)
    box((0.56, 0.02, 0.5), (1.16, 0.93, -0.72), oak(), bevel=0.004, name="board")
    # the ladle rail on the wall, with a hook for each ladle (they hang at x 0.9 + i * 0.11)
    tube([(0.84, 1.3, -1.075), (1.64, 1.3, -1.075)], 0.008, chrome(), name="ladle_rail")
    for x in (0.86, 1.6):
        box((0.02, 0.04, 0.04), (x, 1.3, -1.095), chrome(), name="rail_bracket")
    for i in range(8):
        x = 0.9 + i * 0.11
        tube([(x, 1.3, -1.075), (x, 1.32, -1.06), (x, 1.31, -1.045), (x, 1.295, -1.05)], 0.003, chrome(), caps=False, name="hook")
    # a peel hanging on the right wall
    alu = mat("peel_alu", "#d5d9db", rough=0.25, metal=0.8)
    slab([(-0.15, 0.0), (0.15, 0.0), (0.16, 0.2), (0.12, 0.29), (0.0, 0.32), (-0.12, 0.29), (-0.16, 0.2)], 0.004, (1.611, 1.34, -0.52), alu, rot=(0, -90, 180), name="peel_blade")
    tube([(1.613, 1.34, -0.52), (1.613, 2.0, -0.52)], 0.014, oak(), name="peel_handle")


@model("pass")
def pass_shelf():
    """prop: the heated pass shelf with its heat lamp (origin on the counter top)"""
    s = steel()
    for x in (-0.12, 0.12):
        for z in (-0.08, 0.08):
            cyl(0.01, 0.04, (x, 0.02, z), steel_dark(), seg=8, name="leg")
    box((0.28, 0.025, 0.2), (0, 0.052, 0), s, bevel=0.005, name="plate")
    box((0.25, 0.004, 0.17), (0, 0.066, 0), mat("hot_plate", "#c9784a", rough=0.4, emit="#ff7a3a", emit_k=0.6), name="hot")
    for x in (-0.13, 0.13):
        tube([(x, 0.06, -0.095), (x, 0.43, -0.095), (x, 0.45, -0.06)], 0.009, chrome(), name="gantry")
    box((0.32, 0.045, 0.1), (0, 0.46, -0.02), s, bevel=0.01, name="lamp_housing")
    for x in (-0.07, 0.07):
        sphere(0.025, (x, 0.43, -0.02), mat("heat_bulb", "#ff5a2a", rough=0.3, emit="#ff4a1a", emit_k=3.0), seg=12, rings=8, name="bulb")


@model("bin")
def scrap_bin():
    """prop: the scraps bin on the counter"""
    s = steel()
    lathe([(0.0, 0.0), (0.062, 0.0), (0.068, 0.006), (0.07, 0.15), (0.0, 0.15)], (0, 0, 0), s, seg=24, name="bin")
    lathe([(0.0, 0.15), (0.073, 0.15), (0.074, 0.158), (0.06, 0.175), (0.0, 0.178)], (0, 0, 0), black(), seg=24, name="lid")
    box((0.07, 0.01, 0.03), (0, 0.172, 0.03), mat("flap", "#353535", rough=0.6), rot=(-10, 0, 0), name="flap")


@model("sheeter")
def sheeter():
    """prop: a tabletop dough sheeter"""
    s = steel()
    box((0.28, 0.12, 0.24), (0, 0.06, 0), s, bevel=0.01, name="base")
    for x in (-0.135, 0.135):
        box((0.02, 0.2, 0.2), (x, 0.2, 0), s, bevel=0.006, name="side")
    cyl(0.03, 0.25, (0, 0.2, -0.015), chrome(), axis="x", seg=16, name="roller_a")
    cyl(0.03, 0.25, (0, 0.2, 0.048), chrome(), axis="x", seg=16, name="roller_b")
    box((0.24, 0.004, 0.16), (0, 0.27, -0.1), s, rot=(-35, 0, 0), name="tray_in")
    box((0.24, 0.004, 0.18), (0, 0.14, 0.17), s, rot=(15, 0, 0), name="tray_out")
    cyl(0.03, 0.03, (0.16, 0.2, 0.0), black(), axis="x", seg=16, name="knob")
    box((0.18, 0.006, 0.12), (0, 0.15, 0.17), mat("dough", "#efdcb6", rough=0.8), rot=(15, 0, 0), name="dough_sheet")


# ---------------------------------------------------------------- the ovens (all against the right wall, mouth facing the player)
# The mouth is where the oven view is drawn in service: x 1.04, centred y 1.1, z 0.2, 0.78 wide x 0.62 tall
# (z -0.19..0.59, y 0.79..1.41). Nothing may stand in front of that rectangle.

MZ0, MZ1, MY0, MY1 = -0.19, 0.59, 0.79, 1.41


def _around_mouth(m, x0, x1, z0, z1, y0, y1, name="facade"):
    """a wall of the oven's front with a hole where the mouth is"""
    xc, xs = (x0 + x1) / 2, x1 - x0
    box((xs, y1 - MY1, z1 - z0), (xc, (MY1 + y1) / 2, (z0 + z1) / 2), m, name=name)
    box((xs, MY0 - y0, z1 - z0), (xc, (y0 + MY0) / 2, (z0 + z1) / 2), m, name=name)
    box((xs, MY1 - MY0, MZ0 - z0), (xc, 1.1, (z0 + MZ0) / 2), m, name=name)
    box((xs, MY1 - MY0, z1 - MZ1), (xc, 1.1, (MZ1 + z1) / 2), m, name=name)


def _mouth_frame(m, x=1.04, w=0.05, dark_x=1.052):
    box((0.03, w, MZ1 - MZ0 + 2 * w), (x, MY1 + w / 2, 0.2), m, bevel=0.006, name="mouth_top")
    box((0.03, w, MZ1 - MZ0 + 2 * w), (x, MY0 - w / 2, 0.2), m, bevel=0.006, name="mouth_bottom")
    box((0.03, MY1 - MY0, w), (x, 1.1, MZ0 - w / 2), m, bevel=0.006, name="mouth_l")
    box((0.03, MY1 - MY0, w), (x, 1.1, MZ1 + w / 2), m, bevel=0.006, name="mouth_r")
    # behind the mouth: the dark of the oven (a closed door between services)
    box((0.01, MY1 - MY0, MZ1 - MZ0), (dark_x, 1.1, 0.2), mat("oven_dark", "#1a1412", rough=0.6, emit="#3a1a0c", emit_k=0.6), name="mouth_dark")


def _metal_stand():
    s = steel()
    for x in (1.1, 1.56):
        for z in (-0.22, 0.78):
            box((0.04, 0.6, 0.04), (x, 0.3, z), s, bevel=0.004, name="leg")
    box((0.52, 0.02, 1.04), (1.33, 0.16, 0.28), s, name="shelf")
    box((0.58, 0.04, 1.1), (1.33, 0.58, 0.28), s, bevel=0.006, name="stand_top")
    for i in range(3):
        box((0.42, 0.02, 0.32), (1.33, 0.18 + i * 0.03, 0.0 + i * 0.03), mat("tray", "#9aa3a8", rough=0.4, metal=0.6), name="tray")


def _controls(face_m, knobs, display=True):
    box((0.012, 0.5, 0.13), (1.044, 1.12, 0.735), face_m, bevel=0.004, name="panel")
    for k, y in enumerate((1.22, 1.06, 0.92)[:knobs]):
        cyl(0.024, 0.03, (1.026, y, 0.735), black(), axis="x", seg=16, bevel=0.006, name="knob")
        box((0.004, 0.022, 0.004), (1.01, y + 0.008, 0.735), chrome(), name="knob_mark")
    if display:
        box((0.004, 0.05, 0.1), (1.036, 1.32, 0.735), black(), name="display")
        text("400", (1.033, 1.32, 0.735), mat("led", "#ff5a2a", emit="#ff4a1a", emit_k=2.5), size=0.035, depth=0.002, rot=(0, -90, 0), name="display_text")
    sphere(0.008, (1.036, 1.385, 0.69), mat("lamp_green", "#3cff6a", emit="#3cff6a", emit_k=2.5), seg=8, rings=6, name="power")


def _flue(x=1.33, z=0.2, y0=1.6, r=0.09):
    cyl(r, 1.95 - y0, (x, (y0 + 1.95) / 2, z), black(), seg=16, name="flue")
    cyl(r + 0.015, 0.04, (x, y0 + 0.05, z), black(), seg=16, name="flue_collar")


@model("oven.electric", kind="electric")
@model("oven.gas", kind="gas")
def deck_oven(kind):
    _metal_stand()
    body_m = steel() if kind == "electric" else mat("enamel", "#262626", rough=0.35, metal=0.3)
    trim = steel_dark() if kind == "electric" else steel()
    box((0.56, 1.0, 1.08), (1.33, 1.1, 0.28), body_m, bevel=0.012, name="body")
    box((0.02, 1.0, 1.08), (1.055, 1.1, 0.28), mat("facade", "#3a3a3a" if kind == "electric" else "#1a1a1a", rough=0.4, metal=0.4), name="facade")
    _mouth_frame(trim, dark_x=1.043)
    # a loading ledge under the mouth
    box((0.13, 0.025, 0.86), (0.99, MY0 - 0.06, 0.2), trim, bevel=0.005, name="ledge")
    _controls(black() if kind == "electric" else steel(), 3 if kind == "electric" else 2, display=kind == "electric")
    text("FORNO", (1.035, 1.53, 0.2), chrome(), size=0.06, depth=0.004, rot=(0, -90, 0), name="brand")
    # the vents on top, and the gas oven's flue
    for i in range(5):
        box((0.3, 0.01, 0.02), (1.33, 1.605, 0.0 + i * 0.1), black(), name="vent")
    if kind == "gas":
        _flue(1.4, 0.55, 1.6, 0.07)
        cyl(0.03, 0.3, (1.5, 0.45, 0.65), mat("gas_pipe", "#d4a72c", rough=0.4, metal=0.7), seg=10, name="gas_pipe")


@model("oven.wood", kind="wood")
@model("oven.rotary", kind="rotary")
def dome_oven(kind):
    wood = kind == "wood"
    if wood:
        base_m = mat("brick", "#ffffff", rough=0.85, tex="brick", normal="brick", uvs=0.9)
        face_m = mat("brick_y", "#ffffff", rough=0.85, tex="brick_yellow", normal="brick_yellow", uvs=0.9)
        dome_m = mat("mosaic", "#ffffff", rough=0.35, tex="mosaic", normal="mosaic", uvs=0.5)
        arch_m = mat("stone", "#d9d2c3", rough=0.7, tex="stone", uvs=0.6)
        box((0.61, 0.6, 1.1), (1.305, 0.3, 0.28), base_m, name="base")
        # a log store in the base (decorative)
        box((0.02, 0.36, 0.5), (0.995, 0.26, 0.2), mat("niche", "#1c1714", rough=0.9), name="niche")
        box((0.04, 0.05, 0.6), (0.99, 0.47, 0.2), arch_m, bevel=0.006, name="niche_lintel")
        # the facade with its arch, and the dome behind it
        _around_mouth(face_m, 1.0, 1.06, -0.27, 0.6, 0.6, 1.9)
        for i in range(1, 12):
            a = math.pi * i / 12
            box((0.06, 0.07, 0.1), (1.0, MY1 + math.sin(a) * 0.4, 0.2 + math.cos(a) * 0.4), arch_m, bevel=0.008, rot=(-math.degrees(a) + 90, 0, 0), name="voussoir")
        prof = [(math.cos(math.pi / 2 * i / 10), math.sin(math.pi / 2 * i / 10)) for i in range(11)] + [(0.0, 0.0)]
        lathe([(r, y) for (r, y) in prof], (1.35, 0.78, 0.165), dome_m, seg=28, scale=(0.27, 0.92, 0.43), name="dome")
        box((0.14, 0.03, 0.9), (0.99, MY0 - 0.015, 0.2), arch_m, bevel=0.006, name="landing")
        _mouth_frame(mat("iron", "#2a2522", rough=0.5, metal=0.6), x=1.0, w=0.035, dark_x=1.07)
        _flue(1.25, 0.165, 1.62, 0.09)
        text("FORNO", (0.995, 1.75, 0.2), mat("gold", "#d4a72c", rough=0.3, metal=0.8), size=0.07, depth=0.004, rot=(0, -90, 0), name="brand")
    else:
        _metal_stand()
        dome_m = mat("mosaic_blue", "#ffffff", rough=0.35, tex="mosaic_blue", normal="mosaic_blue", uvs=0.5)
        box((0.56, 0.3, 1.08), (1.33, 0.75, 0.28), steel(), bevel=0.01, name="body")
        prof = [(math.cos(math.pi / 2 * i / 10), math.sin(math.pi / 2 * i / 10)) for i in range(11)] + [(0.0, 0.0)]
        lathe(prof, (1.33, 0.9, 0.28), dome_m, seg=28, scale=(0.28, 0.72, 0.53), name="dome")
        _around_mouth(steel(), 1.03, 1.06, -0.26, 0.82, 0.6, 1.6)
        _mouth_frame(black(), x=1.025, w=0.04, dark_x=1.065)
        _controls(black(), 2)
        _flue(1.33, 0.28, 1.62, 0.08)
        text("ROTARY", (1.028, 1.52, 0.2), black(), size=0.05, depth=0.004, rot=(0, -90, 0), name="brand")


@model("logs")
def logs():
    """prop: logs for the wood oven in an iron rack (origin on the oven base, beside the mouth)"""
    bark = mat("bark", "#5c4330", rough=0.95)
    end = mat("end_grain", "#c9a774", rough=0.8)
    iron = mat("iron", "#2a2522", rough=0.5, metal=0.6)
    import random
    rnd = random.Random(3)
    rows = [(3, 0.0), (2, 0.065), (1, 0.13)]
    for n, y in rows:
        for i in range(n):
            z = (i - (n - 1) / 2) * 0.072
            r = rnd.uniform(0.031, 0.038)
            L = rnd.uniform(0.2, 0.25)
            x = rnd.uniform(-0.015, 0.015)
            cyl(r, L, (x, y + 0.04 + r, z), bark, axis="x", seg=9, name="log")
            for sx in (-1, 1):
                cyl(r * 0.85, 0.004, (x + sx * L / 2, y + 0.04 + r, z), end, axis="x", seg=9, name="log_end")
    for x in (-0.07, 0.07):
        tube([(x, 0.0, -0.13), (x, 0.03, -0.13), (x, 0.03, 0.13), (x, 0.0, 0.13)], 0.008, iron, name="rack_base")
        tube([(x, 0.03, -0.13), (x, 0.22, -0.14)], 0.007, iron, name="rack_up")
        tube([(x, 0.03, 0.13), (x, 0.22, 0.14)], 0.007, iron, name="rack_up")


@model("prep")
def prep():
    s = steel()
    # the counter along the left wall, its front facing the player (+X)
    box((0.6, 0.82, 1.3), (-1.33, 0.47, -0.45), s, bevel=0.01, name="body")
    _feet((-1.58, -1.08), (-1.04, 0.14))
    for z in (-0.78, -0.12):
        box((0.02, 0.62, 0.6), (-1.02, 0.5, z), s, bevel=0.006, name="door")
        box((0.028, 0.022, 0.38), (-1.0, 0.78, z), chrome(), bevel=0.008, name="handle")
    box((0.02, 0.06, 1.26), (-1.025, 0.09, -0.45), steel_dark(), name="kick")
    # the top, round the sink (sink x -1.55..-1.09, z -0.2..0.2)
    box((0.64, 0.04, 0.91), (-1.32, 0.9, -0.655), s, bevel=0.005, name="top_a")
    box((0.64, 0.04, 0.02), (-1.32, 0.9, 0.2), s, name="top_b")
    box((0.07, 0.04, 0.4), (-1.6, 0.9, 0.0), s, name="top_c")
    box((0.08, 0.04, 0.4), (-1.05, 0.9, 0.0), s, name="top_d")
    box((0.04, 0.12, 1.32), (-1.61, 0.98, -0.45), s, name="upstand")
    # the sink bowl and its tap
    for (sx, sz, cx, cz) in [(0.48, 0.01, -1.32, -0.2), (0.48, 0.01, -1.32, 0.2), (0.01, 0.4, -1.56, 0.0), (0.01, 0.4, -1.08, 0.0)]:
        box((sx, 0.2, sz), (cx, 0.81, cz), steel_dark(), name="sink_wall")
    box((0.48, 0.01, 0.4), (-1.32, 0.715, 0.0), steel_dark(), name="sink_floor")
    cyl(0.025, 0.004, (-1.32, 0.722, 0.0), black(), seg=12, name="drain")
    tube([(-1.6, 0.92, 0.12), (-1.6, 1.22, 0.12), (-1.56, 1.27, 0.12), (-1.48, 1.25, 0.12), (-1.44, 1.16, 0.12)], 0.012, chrome(), name="tap")
    box((0.08, 0.015, 0.02), (-1.6, 1.05, 0.16), chrome(), rot=(0, 0, 20), name="tap_lever")
    # the prep tablet's mount on the wall (the screen itself is drawn by the game in service)
    box((0.04, 0.69, 0.92), (-1.627, 1.42, -0.42), black(), bevel=0.012, name="tablet_bezel")
    box((0.004, 0.63, 0.86), (-1.6055, 1.42, -0.42), dark_glass(), name="tablet_screen")
    # deli tubs with coloured lids and a day dot, a chopping board and a knife
    tub = mat("tub", "#f6f6f2", rough=0.35)
    lids = [mat("lid_red", "#c0392b", rough=0.4), mat("lid_white", "#eeeeea", rough=0.4), mat("lid_blue", "#2f6aa8", rough=0.4)]
    dots = [mat("dot_yellow", "#f1c40f", rough=0.5), mat("dot_green", "#2ecc71", rough=0.5), mat("dot_orange", "#e67e22", rough=0.5)]
    for k, (x, z) in enumerate([(-1.46, -0.72), (-1.46, -0.56), (-1.28, -0.66)]):
        box((0.14, 0.13, 0.14), (x, 0.985, z), tub, bevel=0.012, name="tub")
        box((0.15, 0.015, 0.15), (x, 1.057, z), lids[k], bevel=0.005, name="tub_lid")
        cyl(0.012, 0.002, (x + 0.071, 0.99, z), dots[k], axis="x", seg=10, name="day_dot")
    box((0.38, 0.015, 0.28), (-1.3, 0.928, -0.36), mat("board_green", "#3f9a5a", rough=0.6), bevel=0.004, name="chop_board")
    box((0.2, 0.003, 0.04), (-1.28, 0.94, -0.34), chrome(), rot=(0, 20, 0), name="knife_blade")
    box((0.1, 0.016, 0.022), (-1.42, 0.945, -0.385), mat("knife_handle", "#2f6aa8", rough=0.5), rot=(0, 20, 0), bevel=0.004, name="knife_handle")
    # a shelf of jars above
    box((0.24, 0.025, 1.0), (-1.5, 1.9, -0.45), s, bevel=0.004, name="shelf")
    jar_cols = ["#c0392b", "#d9b23f", "#3f6b35", "#8a5c36", "#efe6d0"]
    for k in range(6):
        jm = mat("jar_" + jar_cols[k % 5], jar_cols[k % 5], rough=0.5)
        z = -0.88 + k * 0.17
        lathe([(0.0, 0.0), (0.045, 0.0), (0.05, 0.01), (0.05, 0.12), (0.0, 0.12)], (-1.5, 1.913, z), jm, seg=14, name="jar")
        lathe([(0.0, 0.12), (0.048, 0.12), (0.048, 0.15), (0.0, 0.15)], (-1.5, 1.913, z), mat("jar_lid", "#d0d4d6", rough=0.3, metal=0.7), seg=14, name="jar_lid")
