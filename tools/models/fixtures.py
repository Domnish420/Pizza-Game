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
    box((w * 0.62, 0.036, 0.04), (cx, handle_y, zf + 0.03), red(), bevel=0.014, name="handle")


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
        box((0.46, 0.036, 0.04), (1.22, y + 0.12, -0.245), red(), bevel=0.014, name="drawer_handle")
    box((0.78, 0.06, 0.02), (1.22, 0.09, -0.275), steel_dark(), name="kick")
    # the wooden cutting board (the board you slice on sits on it in service)
    box((0.56, 0.02, 0.5), (1.16, 0.93, -0.72), oak(), bevel=0.004, name="board")
    # the ladle rail on the wall, with a hook for each ladle (they hang at x 0.9 + i * 0.11)
    tube([(0.84, 1.3, -1.075), (1.64, 1.3, -1.075)], 0.008, chrome(), name="ladle_rail")
    for x in (0.86, 1.6):
        box((0.02, 0.04, 0.04), (x, 1.3, -1.095), chrome(), name="rail_bracket")
    for i in range(6):                       # six ladle sizes (data/equipment.json)
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
    lathe([(0.0, 0.0), (0.062, 0.0), (0.068, 0.006), (0.07, 0.15), (0.0, 0.15)], (0, 0, 0), mat("bin_teal", TEAL, rough=0.45), seg=24, name="bin")
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
    cyl(0.035, 0.035, (0.165, 0.2, 0.0), red(), axis="x", seg=16, bevel=0.01, name="knob")
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


def _mouth_frame(m, x=1.04, w=0.05, dark_x=None):
    box((0.03, w, MZ1 - MZ0 + 2 * w), (x, MY1 + w / 2, 0.2), m, bevel=0.006, name="mouth_top")
    box((0.03, w, MZ1 - MZ0 + 2 * w), (x, MY0 - w / 2, 0.2), m, bevel=0.006, name="mouth_bottom")
    box((0.03, MY1 - MY0, w), (x, 1.1, MZ0 - w / 2), m, bevel=0.006, name="mouth_l")
    box((0.03, MY1 - MY0, w), (x, 1.1, MZ1 + w / 2), m, bevel=0.006, name="mouth_r")


# ---------------------------------------------------------------- inside the oven
# The deck you work on in service is a flat plane at YD, from the mouth (x 1.04) back to x 1.6 and across z -0.27..0.67
# (FPWorld maps the oven's 400 x 320 deck map onto it, 0.00235 m a unit). Pizzas waiting to go in sit on the landing
# shelf in front of the mouth (x 0.8..1.02). Each oven is hollow: a chamber lined in soot-dark brick or steel, seen
# through the mouth, with a stone deck, and its heat source (elements, burners, the fire bed).

YD = 0.80


def _chamber(x0, x1, z0, z1, y1, soot, deck_m, bevel):
    """the inside of the oven: an inside-out lining (seen from within, invisible from outside) and the stone deck"""
    box((x1 - x0, y1 - (YD - 0.01), z1 - z0), ((x0 + x1) / 2, (YD - 0.01 + y1) / 2, (z0 + z1) / 2), soot, bevel=bevel, seg=4, flip=True, name="chamber")
    box((x1 - x0, 0.02, z1 - z0), ((x0 + x1) / 2, YD - 0.01, (z0 + z1) / 2), deck_m, bevel=0, name="deck")


def _deck_stone():
    return mat("deck_stone", "#dcc49c", rough=0.85, tex="stone", uvs=0.5)


def _metal_stand():
    s = steel()
    for x in (1.1, 1.56):
        for z in (-0.22, 0.78):
            box((0.045, 0.52, 0.045), (x, 0.32, z), s, name="leg")
            cyl(0.03, 0.03, (x, 0.045, z), black(), axis="z", seg=12, name="castor")
            box((0.05, 0.012, 0.05), (x, 0.066, z), steel_dark(), name="castor_plate")
    box((0.52, 0.022, 1.04), (1.33, 0.2, 0.28), s, name="shelf")
    box((0.58, 0.05, 1.1), (1.33, 0.575, 0.28), s, name="stand_top")
    for i in range(3):
        box((0.42, 0.018, 0.32), (1.33, 0.22 + i * 0.019, 0.02 + i * 0.03), mat("tray", "#9aa3a8", rough=0.4, metal=0.25), name="tray")


def _dial(x, y, z, face_m):
    """a round temperature gauge on a front facing -X"""
    cyl(0.062, 0.024, (x - 0.006, y, z), chrome(), axis="x", seg=24, name="dial_rim")
    cyl(0.052, 0.004, (x - 0.019, y, z), mat("dial_face", "#fbfaf4", rough=0.5), axis="x", seg=24, name="dial_face")
    for i in range(7):
        a = math.radians(-135 + i * 45)
        box((0.002, 0.012, 0.003), (x - 0.0215, y + math.cos(a) * 0.04, z - math.sin(a) * 0.04), black(), rot=(math.degrees(a), 0, 0), name="dial_tick")
    lathe([(0.0, 0.0), (0.04, 0.0), (0.04, 0.003), (0.0, 0.003)], (x - 0.0215, y, z), mat("dial_hot", TOMATO, rough=0.5), seg=18, rot=(0, 0, 90), arc=70, name="dial_band")
    box((0.003, 0.042, 0.005), (x - 0.0235, y + 0.012, z - 0.012), red(), rot=(-40, 0, 0), name="dial_needle")
    cyl(0.007, 0.006, (x - 0.024, y, z), black(), axis="x", seg=10, name="dial_pin")


def _controls(face_m, knobs, display=True):
    """the control column to the right of the mouth: a big temperature dial, knobs, a power lamp"""
    box((0.016, 0.6, 0.16), (1.034, 1.1, 0.705), face_m, name="panel")
    _dial(1.026, 1.3, 0.705, face_m)
    knob_m = mat("knob_" + ("cheese" if face_m.name == "black" else "tomato"), CHEESE if face_m.name == "black" else TOMATO, rough=0.4)
    for k, y in enumerate((1.13, 1.0, 0.88)[:knobs]):
        cyl(0.034, 0.036, (1.008, y, 0.705), knob_m, axis="x", seg=18, bevel=0.012, name="knob")
        box((0.006, 0.026, 0.008), (0.988, y + 0.01, 0.705), white(), name="knob_mark")
    if display:
        box((0.006, 0.05, 0.11), (1.024, 1.2, 0.705), black(), name="display")
        text("400", (1.0205, 1.2, 0.705), mat("led", "#ff5a2a", emit="#ff4a1a", emit_k=2.5), size=0.032, depth=0.002, rot=(0, -90, 0), name="display_text")
    sphere(0.011, (1.024, 1.385, 0.76), mat("lamp_green", "#3cff6a", emit="#3cff6a", emit_k=2.5), seg=10, rings=6, name="power")


def _flue(x=1.33, z=0.2, y0=1.6, r=0.09):
    cyl(r, 1.95 - y0, (x, (y0 + 1.95) / 2, z), black(), seg=18, name="flue")
    cyl(r + 0.018, 0.05, (x, y0 + 0.025, z), black(), seg=18, name="flue_collar")
    cyl(r + 0.012, 0.03, (x, 1.75, z), steel_dark(), seg=18, name="flue_band")


def _handle_bar(x, y, z0, z1, m):
    """a chunky bar across the front, on two posts"""
    for z in (z0, z1):
        box((0.055, 0.03, 0.03), (x + 0.0275, y, z), m, name="bar_post")
    tube([(x, y, z0 - 0.02), (x, y, z1 + 0.02)], 0.016, m, name="bar")


@model("oven.electric", kind="electric")
@model("oven.gas", kind="gas")
def deck_oven(kind):
    """a deck oven on a stand: a stainless (or charcoal enamel) cabinet, its mouth framed like a door opening, a handle
    bar above it, the control column with a big dial on the right, louvres on the side"""
    _metal_stand()
    gas = kind == "gas"
    body_m = steel() if not gas else mat("enamel", CHARCOAL, rough=0.4)
    trim = steel_dark() if not gas else mat("brass", "#c9973a", rough=0.35, metal=0.3)
    front_m = mat("front", "#d9dee1" if not gas else "#2b2f31", rough=0.4, metal=0.2)
    # the cabinet, hollow: bottom, top, back and sides round the baking chamber (x 1.06..1.58, z -0.24..0.64)
    box((0.56, 0.18, 1.08), (1.34, 0.69, 0.28), body_m, name="body_bottom")
    box((0.56, 0.15, 1.08), (1.34, 1.525, 0.28), body_m, name="body_top")
    box((0.04, 0.67, 1.08), (1.6, 1.115, 0.28), body_m, bevel=0, name="body_back")
    box((0.52, 0.67, 0.02), (1.32, 1.115, -0.25), body_m, bevel=0, name="body_side")
    box((0.52, 0.67, 0.18), (1.32, 1.115, 0.73), body_m, bevel=0, name="body_side")
    _around_mouth(front_m, 1.04, 1.06, -0.26, 0.82, 0.6, 1.6)
    _mouth_frame(trim, x=1.035, w=0.045)
    _chamber(1.06, 1.58, -0.24, 0.64, 1.45, mat("oven_steel_in", "#3b3836", rough=0.7), _deck_stone(), 0.03)
    if not gas:
        # heating elements glowing under the ceiling
        glow = mat("element", "#ff7a3a", rough=0.5, emit="#ff5a1a", emit_k=2.2)
        for x in (1.14, 1.32, 1.5):
            tube([(x, 1.415, -0.21), (x, 1.415, 0.61)], 0.008, glow, name="element")
            for z in (-0.2, 0.6):
                box((0.02, 0.035, 0.012), (x, 1.432, z), steel_dark(), bevel=0, name="element_clip")
    else:
        # the burners along the back of the deck
        box((0.03, 0.02, 0.84), (1.555, YD + 0.01, 0.2), black(), bevel=0, name="burner")
        flame_in = mat("gas_flame_in", "#4aa8ff", rough=0.4, emit="#3a9cff", emit_k=3.5)
        for i in range(12):
            cyl(0.011, 0.04, (1.555, YD + 0.04, -0.17 + i * 0.068), flame_in, seg=8, r2=0.002, name="burner_flame")
    # the fold-down landing shelf where pizzas wait to go in
    box((0.24, 0.02, 0.8), (0.92, 0.775, 0.2), steel(), bevel=0.006, name="landing")
    for z in (-0.15, 0.55):
        tube([(1.04, 0.66, z), (0.83, 0.765, z)], 0.008, steel_dark(), name="landing_bracket")
    # a red (or brass) band across the top, the handle bar, the badge
    box((0.585, 0.08, 1.1), (1.335, 1.56, 0.28), mat("top_band", TOMATO, rough=0.45) if not gas else trim, name="top_band")
    _handle_bar(0.985, 1.475, -0.12, 0.52, chrome() if not gas else trim)
    text("FORNO", (1.0405, 1.56, 0.12), white() if not gas else black(), size=0.055, depth=0.004, rot=(0, -90, 0), name="brand")
    _controls(black() if not gas else steel(), 3 if not gas else 2, display=not gas)
    # louvres on the side you see from the counter, vents on top
    for i in range(6):
        box((0.3, 0.014, 0.012), (1.34, 0.85 + i * 0.07, -0.266), black(), name="louvre")
    for i in range(5):
        box((0.3, 0.012, 0.02), (1.34, 1.605, 0.0 + i * 0.1), black(), name="vent")
    if gas:
        # the burners under the deck show through a slot: a row of small blue flames
        box((0.012, 0.06, 0.6), (1.033, 0.67, 0.2), mat("slot", "#141617", rough=0.6), name="flame_slot")
        flame = mat("gas_flame", "#4aa8ff", rough=0.4, emit="#3a9cff", emit_k=3.5)
        for i in range(9):
            cyl(0.012, 0.035, (1.022, 0.668, -0.06 + i * 0.065), flame, seg=8, r2=0.002, name="flame")
        _flue(1.42, 0.6, 1.6, 0.07)
        tube([(1.5, 0.2, 0.7), (1.5, 0.6, 0.7)], 0.02, mat("gas_pipe", "#d4a72c", rough=0.4, metal=0.3), name="gas_pipe")


def _arch_facade(m, x_front, depth, z0, z1, y_spring, y_base):
    """an arch-topped front wall round the mouth: a semicircle over the springline, the pillars either side of the
    mouth, and the wall under it"""
    zc, R = (z0 + z1) / 2, (z1 - z0) / 2
    pts = [(R * math.cos(math.pi * i / 24), R * math.sin(math.pi * i / 24)) for i in range(25)]
    slab(pts, depth, (x_front + depth, y_spring, zc), m, rot=(0, -90, 0), name="facade_arch")
    box((depth, MY0 - y_base, z1 - z0), (x_front + depth / 2, (y_base + MY0) / 2, zc), m, bevel=0, name="facade_low")
    box((depth, y_spring - MY0, MZ0 - z0), (x_front + depth / 2, (MY0 + y_spring) / 2, (z0 + MZ0) / 2), m, bevel=0, name="pillar")
    box((depth, y_spring - MY0, z1 - MZ1), (x_front + depth / 2, (MY0 + y_spring) / 2, (MZ1 + z1) / 2), m, bevel=0, name="pillar")


def _voussoirs(stone_m, key_m, x, y_spring, zc, r_in, r_out, n=13):
    """the stones of the arch, wedge-shaped round the opening, with a keystone"""
    for i in range(n):
        a0 = math.pi * i / n
        a1 = math.pi * (i + 1) / n
        gap = 0.012
        poly = [(math.cos(a0 + gap) * r_in, math.sin(a0 + gap) * r_in), (math.cos(a0 + gap) * r_out, math.sin(a0 + gap) * r_out),
                (math.cos(a1 - gap) * r_out, math.sin(a1 - gap) * r_out), (math.cos(a1 - gap) * r_in, math.sin(a1 - gap) * r_in)]
        poly.reverse()
        slab(poly, 0.035, (x, y_spring, zc), key_m if i == n // 2 else stone_m, rot=(0, -90, 0), name="voussoir")


@model("oven.wood", kind="wood")
@model("oven.rotary", kind="rotary")
def dome_oven(kind):
    """a Neapolitan-style dome oven: brick base with a log store, a stone hearth shelf in front of the mouth, an
    arch-topped front covered in mosaic with a stone arch, the dome behind, a capped chimney through the hood.
    The rotary version is the same shape in steel and blue mosaic on a steel stand."""
    wood = kind == "wood"
    XF = 1.0                                     # the front face of the facade
    z0, z1 = -0.27, 0.67                         # the facade's width (the mouth is z -0.19..0.59)
    if wood:
        base_m = mat("brick", "#ffffff", rough=0.85, tex="brick", uvs=0.9)
        face_m = mat("mosaic", "#ffffff", rough=0.4, tex="mosaic", uvs=0.45)
        dome_m = mat("mosaic_dome", "#ffffff", rough=0.4, tex="mosaic", uvs=0.5)
        stone_m = mat("stone", "#e3dccd", rough=0.7, tex="stone", uvs=0.6)
        key_m = mat("gold", "#d9a93a", rough=0.35, metal=0.3)
        # the brick base, with a log store in it
        box((0.66, 0.6, 1.12), (1.29, 0.3, 0.27), base_m, name="base")
        box((0.012, 0.34, 0.62), (0.955, 0.27, 0.2), mat("niche", "#241b16", rough=0.9), bevel=0, name="niche")
        box((0.03, 0.04, 0.68), (0.953, 0.46, 0.2), stone_m, name="niche_lintel")
        bark = mat("bark", "#6b4a2b", rough=0.9)
        end = mat("end_grain", "#d6b27a", rough=0.8)
        for row, n in enumerate((5, 4, 3)):
            for i in range(n):
                z = 0.2 + (i - (n - 1) / 2) * 0.1
                y = 0.15 + row * 0.085
                cyl(0.04, 0.012, (0.943, y, z), end, axis="x", seg=12, name="log_end")
                torus(0.04, 0.006, (0.943, y, z), bark, seg=12, rseg=4, rot=(0, 0, 90), name="log_bark")
    else:
        _metal_stand()
        base_m = steel()
        face_m = mat("mosaic_blue", "#ffffff", rough=0.4, tex="mosaic_blue", uvs=0.45)
        dome_m = mat("mosaic_blue_dome", "#ffffff", rough=0.4, tex="mosaic_blue", uvs=0.5)
        stone_m = steel_dark()
        key_m = red()
        box((0.6, 0.03, 1.1), (1.31, 0.615, 0.27), steel(), name="stand_cap")
    # the hearth: the deck's level behind the facade, and the shelf in front of the mouth
    yb = 0.6 if wood else 0.63
    box((0.55, YD - 0.02 - yb, 0.89), (1.335, (yb + YD - 0.02) / 2, 0.165), stone_m if not wood else base_m, bevel=0, name="hearth")
    box((0.24, 0.05, 0.98), (XF - 0.12, MY0 - 0.025, 0.2), stone_m, name="hearth_shelf")      # the landing (x 0.78..1.02)
    for z in (-0.18, 0.58):
        slab([(0.2, 0.0), (0.2, 0.15), (0.0, 0.15)], 0.05, (XF - 0.2, MY0 - 0.2, z - 0.025), stone_m, name="corbel")
    # inside: a soot-dark vault over the stone deck (x 1.06..1.6, z -0.26..0.63: clear of the logs at the side)
    _chamber(1.06, 1.6, -0.26, 0.63, 1.4, mat("soot", "#3a2b24", rough=0.9) if wood else mat("oven_steel_in", "#3b3836", rough=0.7), _deck_stone(), 0.16)
    if wood:
        # the fire bed on the left: embers in their ash, charred logs across them (the flames are the game's)
        cyl(0.13, 0.008, (1.33, YD + 0.004, -0.135), mat("ash", "#8a8580", rough=0.95), seg=20, name="ash")
        blobs([("ellipsoid", (1.33, YD + 0.012, -0.135), 0.1, (1.0, 0.22, 0.9))], mat("embers", "#ff6a1a", rough=0.6, emit="#ff4a0a", emit_k=2.2), res=0.012, name="embers", tris=200)
        char = mat("charred", "#2a1d16", rough=0.95)
        for (ang, dy) in ((20, 0.03), (-35, 0.045), (80, 0.06)):
            cyl(0.028, 0.24, (1.33, YD + dy, -0.135), char, axis="x", seg=10, rot=(0, ang, 0), name="charred_log")
    else:
        # the gas burner on the left, and the turning hearth itself
        box((0.22, 0.025, 0.06), (1.33, YD + 0.0125, -0.135), steel_dark(), bevel=0, name="burner")
        cyl(0.24, 0.004, (1.324, YD + 0.002, 0.296), mat("turntable", "#cdb48a", rough=0.85), seg=40, name="turntable")
        cyl(0.03, 0.01, (1.324, YD + 0.005, 0.296), steel_dark(), seg=16, name="hub")
    # the mosaic front, its stone arch, the iron mouth frame
    _arch_facade(face_m, XF, 0.06, z0, z1, MY1, yb)
    _voussoirs(stone_m, key_m, XF, MY1, 0.2, 0.4, 0.47)
    _mouth_frame(mat("iron", "#3a332e", rough=0.5, metal=0.3), x=XF - 0.008, w=0.03)
    # the entrance tunnel behind the mouth: side walls and a roof back to x 1.19, so the dome can open into it
    tun = base_m if wood else steel()
    for (za, zb) in ((z0, MZ0), (MZ1, z1)):
        box((0.13, MY1 + 0.09 - YD, zb - za), (1.125, (YD + MY1 + 0.09) / 2, (za + zb) / 2), tun, bevel=0, name="tunnel_wall")
    box((0.13, 0.09, z1 - z0), (1.125, MY1 + 0.045, (z0 + z1) / 2), tun, bevel=0, name="tunnel_roof")
    # the dome: whole round the back and sides; over the tunnel only its top (the front below that opens into the vault)
    prof = [(math.cos(math.pi / 2 * i / 12), math.sin(math.pi / 2 * i / 12)) for i in range(13)] + [(0.0, 0.0)]
    lathe(prof, (1.34, MY0, 0.2), dome_m, seg=30, scale=(0.27, 1.06, 0.47), a0=326, arc=248, name="dome")
    t0 = math.asin(0.66)
    top = [(math.cos(t0 + (math.pi / 2 - t0) * i / 6), math.sin(t0 + (math.pi / 2 - t0) * i / 6)) for i in range(7)]
    lathe(top, (1.34, MY0, 0.2), dome_m, seg=12, scale=(0.27, 1.06, 0.47), a0=214, arc=112, name="dome_front")
    # the chimney, through the hood
    _flue(1.3, 0.2, 1.72, 0.08)
    cyl(0.1, 0.04, (1.3, 1.73, 0.2), stone_m, seg=18, name="flue_base")
    if not wood:
        # the rotary's switch and lamp on the wall under the mouth
        cyl(0.03, 0.03, (0.985, 0.68, 0.48), red(), axis="x", seg=16, bevel=0.01, name="knob")
        sphere(0.011, (0.995, 0.68, 0.4), mat("lamp_green", "#3cff6a", emit="#3cff6a", emit_k=2.5), seg=10, rings=6, name="power")


# the inside-out chamber stays its own part, so the checks can tell it is meant to be inside out
deck_oven.keep = ("chamber",)
dome_oven.keep = ("chamber",)


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
            z = (i - (n - 1) / 2) * 0.066
            r = rnd.uniform(0.031, 0.038)
            L = rnd.uniform(0.2, 0.25)
            x = rnd.uniform(-0.015, 0.015)
            cyl(r, L, (x, y + 0.04 + r, z), bark, axis="x", seg=9, name="log")
            for sx in (-1, 1):
                cyl(r * 0.85, 0.004, (x + sx * L / 2, y + 0.04 + r, z), end, axis="x", seg=9, name="log_end")
    for x in (-0.07, 0.07):
        tube([(x, 0.0, -0.11), (x, 0.03, -0.11), (x, 0.03, 0.11), (x, 0.0, 0.11)], 0.008, iron, name="rack_base")
        tube([(x, 0.03, -0.11), (x, 0.22, -0.115)], 0.007, iron, name="rack_up")
        tube([(x, 0.03, 0.11), (x, 0.22, 0.115)], 0.007, iron, name="rack_up")


@model("prep")
def prep():
    s = steel()
    # the counter along the left wall, its front facing the player (+X)
    box((0.6, 0.82, 1.3), (-1.33, 0.47, -0.45), s, bevel=0.01, name="body")
    _feet((-1.58, -1.08), (-1.04, 0.14))
    for z in (-0.78, -0.12):
        box((0.02, 0.62, 0.6), (-1.02, 0.5, z), s, bevel=0.006, name="door")
        box((0.04, 0.036, 0.38), (-0.995, 0.78, z), red(), bevel=0.014, name="handle")
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
