"""The props: the back of house (fridge, freezer, dry store, cleaning, traps, boxes, dough), the small things on the
counter (pans, ladles, tickets), a dining table and a mouse. Each is built round its own origin with its base at
y = 0, and the game places it (see the positions in ART_KEYS.md)."""
import random
from lib import *
from common import *


@model("fridge")
def fridge():
    """upright fridge, door facing -Z; the thermometer hangs on the door at (0.17, 1.45, -0.35)"""
    s = steel()
    box((0.66, 1.62, 0.64), (0, 0.93, 0.0), s, bevel=0.012, name="cabinet")
    box((0.6, 1.5, 0.03), (0, 0.9, -0.335), s, bevel=0.012, name="door")
    box((0.62, 1.52, 0.012), (0, 0.9, -0.325), mat("gasket", "#2b2b2b", rough=0.8), name="gasket")
    box((0.66, 0.16, 0.64), (0, 1.78, 0.0), black(), bevel=0.01, name="top_housing")
    for i in range(6):
        box((0.56, 0.012, 0.01), (0, 1.73 + i * 0.022, -0.322), steel_dark(), name="louvre")
    box((0.1, 0.035, 0.008), (-0.2, 1.8, -0.324), black(), name="display")
    text("3.0", (-0.2, 1.8, -0.319), mat("led_green", "#5cff8a", emit="#4cff7a", emit_k=2.0), size=0.024, depth=0.001, rot=(0, 180, 0), name="display_text")
    box((0.025, 0.42, 0.035), (0.25, 0.95, -0.37), chrome(), bevel=0.01, name="handle")
    for y in (0.75, 1.15):
        box((0.03, 0.03, 0.03), (0.25, y, -0.355), chrome(), name="handle_post")
    for x in (-0.28, 0.28):
        for z in (-0.26, 0.26):
            cyl(0.025, 0.12, (x, 0.06, z), black(), seg=10, name="castor")
    box((0.6, 0.1, 0.02), (0, 0.17, -0.33), steel_dark(), name="kick")
    text("FRIGO", (0, 1.62, -0.352), black(), size=0.03, depth=0.002, rot=(0, 180, 0), name="brand")


@model("thermometer")
def thermometer():
    """a dial thermometer on the fridge door, its face toward -Z"""
    cyl(0.052, 0.02, (0, 0, 0), chrome(), axis="z", seg=28, bevel=0.006, name="rim")
    cyl(0.044, 0.002, (0, 0, -0.0105), mat("dial", "#fbfaf6", rough=0.6), axis="z", seg=28, name="face")
    lathe([(0.03, -0.001), (0.042, -0.001), (0.042, 0.001), (0.03, 0.001)], (0, 0, -0.0115), mat("cold_band", "#3c8ad9", rough=0.6), seg=28, rot=(90, 0, 0), arc=80, name="band")
    for i in range(9):
        a = math.radians(-120 + i * 30)
        box((0.002, 0.009, 0.001), (math.sin(a) * 0.036, math.cos(a) * 0.036, -0.0125), black(), rot=(0, 0, -math.degrees(a)), name="tick")
    box((0.003, 0.034, 0.001), (0.006, 0.012, -0.013), red(), rot=(0, 0, -25), name="needle")
    cyl(0.005, 0.003, (0, 0, -0.013), black(), axis="z", seg=10, name="pivot")


@model("freezer")
def freezer():
    """a chest freezer, lid handle toward -Z"""
    body = mat("freezer_white", "#eef2f4", rough=0.35, metal=0.1)
    box((0.6, 0.82, 0.45), (0, 0.45, 0), body, bevel=0.015, name="body")
    box((0.6, 0.06, 0.45), (0, 0.89, 0), body, bevel=0.015, name="lid")
    box((0.58, 0.012, 0.43), (0, 0.86, 0), mat("seal", "#3a3a3a", rough=0.8), name="seal")
    box((0.22, 0.03, 0.04), (0, 0.86, -0.24), mat("freezer_handle", "#8f9a9f", rough=0.4), bevel=0.008, name="handle")
    box((0.6, 0.04, 0.45), (0, 0.02, 0), black(), name="plinth")
    for i in range(5):
        box((0.008, 0.02, 0.2), (0.302, 0.15 + i * 0.035, 0.05), steel_dark(), name="vent")
    sphere(0.008, (0.22, 0.8, -0.228), mat("lamp_green", "#3cff6a", emit="#3cff6a", emit_k=2.5), seg=8, rings=6, name="lamp")


@model("drystore")
def drystore():
    """chrome wire shelving against the back wall with flour, tins, oil and jars"""
    wire = chrome()
    for x in (-0.44, 0.44):
        for z in (-0.18, 0.18):
            cyl(0.012, 1.8, (x, 0.9, z), wire, seg=10, name="post")
    for y in (0.1, 0.6, 1.1, 1.6):
        box((0.9, 0.012, 0.38), (0, y, 0), mat("shelf_mat", "#dfe3e5", rough=0.3, metal=0.7), bevel=0.003, name="shelf")
        for z in (-0.19, 0.19):
            cyl(0.006, 0.9, (0, y + 0.005, z), wire, axis="x", seg=8, name="rail")
    paper = kraft()
    print_red = mat("sack_print", "#b8352b", rough=0.7)
    ink = mat("ink", "#2a2a2a", rough=0.7)
    # flour sacks on the bottom shelf
    for i in range(3):
        x = -0.28 + i * 0.28
        blobs([("ellipsoid", (x, 0.27, 0), 0.16, (0.8, 1.05, 0.62)), ("ellipsoid", (x, 0.37, 0), 0.12, (0.85, 0.6, 0.6))], paper, res=0.025, name="sack", tris=200)
        box((0.22, 0.05, 0.005), (x, 0.3, -0.105), print_red, name="sack_band")
        text("00", (x, 0.3, -0.1), mat("sack_text", "#fbf3e3", rough=0.7), size=0.04, depth=0.002, rot=(0, 180, 0), name="sack_text")
    # tomato tins and oil cans on the second shelf
    tin_side = mat("tin_label", "#c9452f", rough=0.5)
    tin_top = mat("tin_metal", "#cfd3d5", rough=0.3, metal=0.8)
    for i in range(5):
        x = -0.34 + i * 0.13
        cyl(0.05, 0.12, (x, 0.666, -0.06), tin_side, seg=16, name="tin")
        cyl(0.051, 0.008, (x, 0.73, -0.06), tin_top, seg=16, name="tin_top")
        cyl(0.051, 0.008, (x, 0.61, -0.06), tin_top, seg=16, name="tin_bottom")
        box((0.06, 0.03, 0.002), (x, 0.67, -0.11), mat("tin_label_band", "#f0d36a", rough=0.5), name="tin_band")
    oil = mat("oil_can", "#3f6b35", rough=0.4, metal=0.4)
    for i in range(2):
        box((0.11, 0.24, 0.11), (-0.25 + i * 0.13, 0.726, 0.1), oil, bevel=0.008, name="oil_can")
        cyl(0.012, 0.03, (-0.25 + i * 0.13, 0.858, 0.1), black(), seg=8, name="oil_cap")
    # jars, packets and boxes on the third, boxes of dry goods on the top
    jar_glass = mat("jar_glass", "#e6dcc4", rough=0.15, metal=0.05)
    cols = ["#6b8f3a", "#d9b23f", "#8a5c36", "#b8352b"]
    for i in range(4):
        x = -0.32 + i * 0.2
        lathe([(0.0, 0.0), (0.05, 0.0), (0.055, 0.02), (0.055, 0.17), (0.04, 0.19), (0.0, 0.19)], (x, 1.106, -0.04), jar_glass, seg=14, name="jar")
        cyl(0.042, 0.03, (x, 1.31, -0.04), mat("lid_" + cols[i], cols[i], rough=0.4, metal=0.3), seg=14, name="jar_lid")
    for i in range(3):
        box((0.18, 0.24, 0.14), (-0.24 + i * 0.24, 1.73, 0.0), mat("pack_%d" % i, ["#e8dcc0", "#c9d6e3", "#e3c9c9"][i], rough=0.7), bevel=0.006, name="pack")
        box((0.181, 0.06, 0.141), (-0.24 + i * 0.24, 1.76, 0.0), mat("pack_band_%d" % i, ["#b8352b", "#2f5d8a", "#3f6b35"][i], rough=0.6), name="pack_band")


@model("mop")
def mop():
    """mop bucket with its wringer, and the mop"""
    yel = mat("bucket_yellow", "#e8c23a", rough=0.45)
    lathe([(0.0, 0.04), (0.15, 0.04), (0.17, 0.3), (0.175, 0.31), (0.16, 0.31), (0.145, 0.06), (0.0, 0.06)], (0, 0, 0), yel, seg=20, name="bucket")
    cyl(0.14, 0.004, (0, 0.2, 0), mat("water", "#8aa7a0", rough=0.1, metal=0.1), seg=20, name="water")
    for (x, z) in [(-0.12, -0.12), (0.12, -0.12), (-0.12, 0.12), (0.12, 0.12)]:
        sphere(0.025, (x, 0.025, z), black(), seg=8, rings=6, name="wheel")
    box((0.2, 0.12, 0.14), (0.0, 0.36, 0.08), mat("wringer", "#3a5f9a", rough=0.5), bevel=0.01, name="wringer")
    tube([(0.08, 0.3, 0.08), (0.08, 0.6, 0.12)], 0.012, mat("wringer_arm", "#3a5f9a", rough=0.5), name="wringer_arm")
    tube([(-0.05, 0.12, -0.04), (0.06, 1.3, -0.16)], 0.014, mat("mop_stick", "#9aa0a3", rough=0.3, metal=0.7), name="mop_stick")
    blobs([("ball", (-0.05, 0.12, -0.04), 0.07), ("ellipsoid", (-0.05, 0.1, -0.04), 0.08, (1.0, 0.5, 1.0))], mat("mop_head", "#dfe6e8", rough=0.95), res=0.02, name="mop_head", tris=200)


@model("spray")
def spray():
    """a spray bottle of sanitiser"""
    lathe([(0.0, 0.0), (0.033, 0.0), (0.036, 0.01), (0.036, 0.12), (0.026, 0.15), (0.016, 0.16), (0.0, 0.16)], (0, 0, 0), mat("sanitiser", "#4a9ad9", rough=0.2, alpha=0.85), seg=16, name="bottle")
    box((0.03, 0.05, 0.06), (0, 0.185, 0.01), white(), bevel=0.008, name="head")
    box((0.022, 0.04, 0.012), (0, 0.15, -0.02), white(), rot=(20, 0, 0), bevel=0.004, name="trigger")
    box((0.012, 0.012, 0.02), (0, 0.195, -0.028), mat("nozzle", "#c0392b", rough=0.5), name="nozzle")
    box((0.05, 0.05, 0.002), (0, 0.07, -0.037), mat("spray_label", "#ffffff", rough=0.6), name="label")


@model("trapbox")
def trapbox():
    """a box of mouse traps"""
    box((0.3, 0.14, 0.24), (0, 0.07, 0), kraft(), bevel=0.004, name="box")
    box((0.3, 0.004, 0.24), (0, 0.205, 0.14), kraft(), rot=(-70, 0, 0), name="flap")
    text("TRAPS", (0, 0.08, -0.121), mat("trap_ink", "#b8352b", rough=0.7), size=0.045, depth=0.002, rot=(0, 180, 0), name="label")
    wood = oak()
    for i in range(3):
        box((0.1, 0.012, 0.05), (-0.08 + i * 0.08, 0.146, -0.02 + i * 0.03), wood, rot=(0, 15 * i, 0), name="trap")
        box((0.08, 0.003, 0.003), (-0.08 + i * 0.08, 0.155, -0.02 + i * 0.03), chrome(), rot=(0, 15 * i, 0), name="trap_bar")


@model("boxes")
def boxes():
    """the wall shelf of pizza boxes; the game grows the 'flat' and 'folded' stacks from their bases"""
    box((0.62, 0.02, 0.4), (0, 0, 0), steel(), bevel=0.004, name="shelf")
    for x in (-0.26, 0.26):
        box((0.02, 0.18, 0.02), (x, -0.08, -0.18), steel_dark(), rot=(45, 0, 0), name="bracket")
    k = kraft()
    flat_root = empty("flat", (-0.15, 0.01, 0))
    box((0.3, 0.12, 0.34), (-0.15, 0.07, 0), k, name="flat_stack", parent=None)
    for i in range(5):
        box((0.302, 0.002, 0.342), (-0.15, 0.025 + i * 0.022, 0), mat("flat_line", "#8a6a44", rough=0.9), name="flat_line")
    folded_root = empty("folded", (0.17, 0.01, 0))
    for i in range(5):
        box((0.27, 0.036, 0.3), (0.17 + (i % 2) * 0.006, 0.03 + i * 0.039, 0.003 * (i % 3)), k, bevel=0.004, name="folded_box")
    text("PIZZA", (0.17, 0.2, 0.154), mat("box_ink", "#b8352b", rough=0.7), size=0.04, depth=0.002, name="box_logo")
    # put each stack under its named point (origin at the stack's base), so the game can scale them
    flat_parts = [o for o in bpy.context.scene.objects if o.name.startswith(("flat_stack", "flat_line"))]
    fold_parts = [o for o in bpy.context.scene.objects if o.name.startswith(("folded_box", "box_logo"))]
    for parts, root in ((flat_parts, flat_root), (fold_parts, folded_root)):
        j = join(parts, root.name + "_mesh")
        j.data.transform(Matrix.Translation(-root.location))
        j.parent = root


boxes.keep = ("flat_mesh", "folded_mesh")


@model("mixer")
def mixer():
    """a countertop spiral mixer, its front toward +X (the room)"""
    body = mat("mixer_body", "#e9e7e2", rough=0.35, metal=0.2)
    box((0.3, 0.07, 0.34), (0, 0.035, 0), body, bevel=0.015, name="base")
    box((0.1, 0.42, 0.14), (-0.1, 0.28, 0), body, bevel=0.02, name="column")
    box((0.3, 0.1, 0.16), (0.02, 0.5, 0), body, bevel=0.03, name="head")
    lathe([(0.0, 0.07), (0.1, 0.07), (0.13, 0.1), (0.135, 0.26), (0.128, 0.26), (0.123, 0.1), (0.095, 0.078), (0.0, 0.078)], (0.04, 0, 0), steel(), seg=24, name="bowl")
    blobs([("ellipsoid", (0.04, 0.14, 0), 0.13, (0.9, 0.45, 0.9)), ("ball", (0.07, 0.17, 0.03), 0.06)], mat("dough", "#efdcb6", rough=0.8), res=0.02, name="dough", tris=300)
    pts = [(0.04 + math.cos(t * 0.6) * 0.03, 0.44 - t * 0.012, math.sin(t * 0.6) * 0.03) for t in range(22)]
    tube(pts, 0.007, chrome(), name="hook")
    tube([(-0.08, 0.27, -0.13), (0.08, 0.3, -0.13), (0.17, 0.3, 0.0), (0.08, 0.3, 0.13), (-0.08, 0.27, 0.13)], 0.005, chrome(), caps=False, name="guard")
    for k, c in enumerate(("#3cb371", "#c0392b")):
        cyl(0.012, 0.012, (0.175, 0.5, -0.03 + k * 0.06), mat("btn_" + c, c, rough=0.4), axis="x", seg=10, name="button")


@model("bowl")
def bowl():
    """a stainless mixing bowl with a dough in it"""
    lathe([(0.0, 0.0), (0.09, 0.0), (0.15, 0.08), (0.16, 0.12), (0.165, 0.125), (0.155, 0.125), (0.145, 0.085), (0.085, 0.008), (0.0, 0.008)], (0, 0, 0), steel(), seg=28, name="bowl")
    blobs([("ellipsoid", (0, 0.055, 0), 0.1, (1.0, 0.5, 1.0)), ("ball", (0.02, 0.07, 0.01), 0.05)], mat("dough", "#efdcb6", rough=0.8), res=0.02, name="dough", tris=300)
    box((0.1, 0.004, 0.07), (0.12, 0.13, 0.05), mat("scraper", "#e3e3e0", rough=0.5), rot=(0, 30, -20), bevel=0.003, name="scraper")


@model("dough_trays")
def dough_trays():
    """lidded proving trays, stacked; the top one has a clear lid over its dough balls"""
    tray = mat("tray_white", "#f2f3f0", rough=0.35)
    for i in range(3):
        y = i * 0.065
        box((0.3, 0.06, 0.19), (0, y + 0.03, 0), tray, bevel=0.008, name="tray")
        box((0.302, 0.006, 0.192), (0, y + 0.06, 0), mat("tray_rim", "#dfe2df", rough=0.35), name="tray_rim")
    dough = mat("dough", "#efdcb6", rough=0.8)
    els = []
    for r in range(2):
        for c in range(3):
            els.append(("ellipsoid", (-0.09 + c * 0.09, 0.165, -0.045 + r * 0.09), 0.042, (1.0, 0.7, 1.0)))
    blobs(els, dough, res=0.012, name="balls", tris=500)
    box((0.3, 0.004, 0.19), (0, 0.195, 0), glass(), name="lid")


@model("clipboard")
def clipboard():
    """the checklist on its clipboard, hanging on the wall, facing +Z"""
    box((0.24, 0.32, 0.008), (0, 0, 0), mat("hardboard", "#8a6a40", rough=0.7), bevel=0.003, name="board")
    box((0.21, 0.27, 0.002), (0, -0.015, 0.005), mat("paper", "#fbf8ef", rough=0.9), name="paper")
    ink = mat("pencil", "#7a7f84", rough=0.8)
    for i in range(7):
        y = 0.08 - i * 0.034
        box((0.014, 0.014, 0.001), (-0.08, y, 0.0065), ink, name="checkbox")
        box((0.13, 0.003, 0.001), (0.0, y, 0.0065), ink, name="line")
    box((0.1, 0.035, 0.02), (0, 0.145, 0.01), chrome(), bevel=0.006, name="clip")
    cyl(0.006, 0.02, (0, 0.17, -0.005), chrome(), axis="z", seg=8, name="nail")


@model("sign")
def sign():
    """the chalkboard sign hanging in the hatch (the game writes OPEN / LOCK UP on it)"""
    frame = walnut()
    box((0.42, 0.24, 0.02), (0, 0, -0.005), frame, bevel=0.006, name="frame")
    box((0.38, 0.2, 0.004), (0, 0, 0.004), mat("chalkboard", "#1e2a22", rough=0.85), name="board")
    for x in (-0.15, 0.15):
        tube([(x, 0.12, -0.005), (x * 0.7, 0.19, -0.005)], 0.0025, mat("string", "#cdbf9a", rough=0.9), name="string")
        cyl(0.008, 0.012, (x, 0.115, 0.002), chrome(), axis="z", seg=8, name="eyelet")


@model("crates")
def crates():
    """today's delivery by the back door: a taped box, a crate of tomatoes and a sack of flour"""
    k = kraft()
    box((0.5, 0.3, 0.38), (0, 0.15, 0), k, bevel=0.006, name="carton")
    box((0.08, 0.002, 0.385), (0, 0.301, 0), mat("tape", "#c9a36a", rough=0.4), name="tape")
    text("FRAGILE", (0.252, 0.17, 0), mat("carton_ink", "#b8352b", rough=0.7), size=0.04, depth=0.002, rot=(0, 90, 0), name="carton_text")
    crate = mat("crate_green", "#2e8a4f", rough=0.5)
    box((0.44, 0.02, 0.34), (0.03, 0.31, 0.01), crate, name="crate_floor")
    for (sx, sz, cx, cz) in [(0.44, 0.02, 0.03, -0.16), (0.44, 0.02, 0.03, 0.18), (0.02, 0.34, -0.19, 0.01), (0.02, 0.34, 0.25, 0.01)]:
        box((sx, 0.14, sz), (cx, 0.39, cz), crate, name="crate_wall")
    tom = mat("tomato", "#d6402b", rough=0.35)
    rnd = random.Random(5)
    r = 0.038
    for ix in range(5):
        for iz in range(4):
            x = 0.03 + (ix - 2) * 0.078 + rnd.uniform(-0.006, 0.006)
            z = 0.01 + (iz - 1.5) * 0.078 + rnd.uniform(-0.006, 0.006)
            sphere(r, (x, 0.32 + r, z), tom, seg=10, rings=7, name="tomato")          # on the crate floor
    for (ix, iz) in [(0.5, 0.5), (1.5, 1.5), (2.5, 0.5), (1.5, -0.5), (3.0, 1.2)]:
        sphere(r, (0.03 + (ix - 2) * 0.078, 0.32 + r + 0.055, 0.01 + (iz - 1.0) * 0.078), tom, seg=10, rings=7, name="tomato")
    blobs([("ellipsoid", (-0.34, 0.176, 0.08), 0.16, (0.55, 1.1, 0.5))], k, res=0.025, name="flour_sack", tris=200)


@model("pan")
def pan():
    """one gastronorm pan, 0.1 wide (the game stretches it to fit the rail), 0.2 deep, rim at y 0.03"""
    s = mat("pan_steel", "#d3d8da", rough=0.25, metal=0.75)
    W, D, H, T = 0.096, 0.196, 0.06, 0.002
    box((W - 2 * T, T, D - 2 * T), (0, -0.03 + T / 2, 0), s, name="bottom")
    for z in (-D / 2 + T / 2, D / 2 - T / 2):
        box((W, H, T), (0, 0, z), s, name="wall")
    for x in (-W / 2 + T / 2, W / 2 - T / 2):
        box((T, H, D), (x, 0, 0), s, name="wall")
    for z in (-D / 2 - 0.0025, D / 2 + 0.0025):
        box((W + 0.004, T, 0.005), (0, 0.03, z), s, name="rim")
    for x in (-W / 2 - 0.001, W / 2 + 0.001):
        box((0.002, T, D + 0.01), (x, 0.03, 0), s, name="rim")


LADLE_COLS = {1: "#c0392b", 2: "#2f6aa8", 3: "#7a7f84", 4: "#3cb371", 5: "#8e44ad", 6: "#e6b422", 7: "#e67e22", 8: "#2a2a2a"}


def _ladle(oz):
    """a portion ladle hanging from its hook at the origin, bowl at the bottom facing the player (+Z)"""
    s = chrome()
    r = (3 * oz * 29.6 / (2 * math.pi)) ** (1 / 3) / 100.0
    tube([(0, 0.0, -0.006), (0, 0.012, 0.0), (0, 0.0, 0.008), (0, -0.02, 0.01), (0, -0.25, 0.01)], 0.004, s, name="handle")
    box((0.016, 0.07, 0.01), (0, -0.07, 0.012), mat("grip_%d" % oz, LADLE_COLS.get(oz, "#7a7f84"), rough=0.5), bevel=0.004, name="grip")
    prof = [(0.0, -r), ]
    for i in range(1, 9):
        a = math.pi / 2 * i / 8
        prof.append((math.sin(a) * r, -math.cos(a) * r))
    prof += [(r * 0.97, 0.0)]
    for i in range(8, 0, -1):
        a = math.pi / 2 * i / 8
        prof.append((math.sin(a) * r * 0.93, -math.cos(a) * r * 0.93 + 0.0015))
    prof.append((0.0, -r * 0.93 + 0.0015))
    lathe(prof, (0, -0.25 - r, 0.01 + r * 0.2), s, seg=18, rot=(90, 0, 0), name="bowl")
    text(str(oz), (0, -0.05, 0.018), mat("grip_text", "#ffffff", rough=0.5), size=0.012, depth=0.001, name="oz")


for _oz in range(1, 9):
    model("ladle.%d" % _oz, oz=_oz)(_ladle)


@model("ticket")
def ticket():
    """a paper order ticket, centred on its origin, facing +Z (the game prints the order on it)"""
    box((0.19, 0.26, 0.001), (0, 0, -0.0006), mat("ticket_paper", "#fbf8ef", rough=0.95), name="paper")
    box((0.19, 0.012, 0.0012), (0, -0.124, -0.0006), mat("ticket_tear", "#ece6d6", rough=0.95), name="tear")
    box((0.05, 0.03, 0.012), (0, 0.135, -0.005), mat("ticket_clip", "#2a2a2a", rough=0.4, metal=0.4), bevel=0.003, name="clip")


@model("table")
def table():
    """a dining table, top at 0.765, with four bistro chairs 0.62 m out facing it"""
    top = walnut()
    iron = mat("cast_iron", "#26282a", rough=0.45, metal=0.5)
    box((0.8, 0.04, 0.8), (0, 0.745, 0), top, bevel=0.008, name="top")
    cyl(0.04, 0.69, (0, 0.375, 0), iron, seg=12, name="column")
    for a in range(4):
        ang = math.radians(45 + a * 90)
        box((0.36, 0.03, 0.05), (math.cos(ang) * 0.16, 0.015, math.sin(ang) * 0.16), iron, rot=(0, -math.degrees(ang), 0), bevel=0.008, name="foot")
    cyl(0.06, 0.03, (0, 0.71, 0), iron, seg=12, name="collar")
    # the caddy at the far side: salt, pepper, oil, a little vase
    for k, (c, x) in enumerate([("#f2f2ef", -0.12), ("#2a2a2a", -0.07)]):
        lathe([(0.0, 0.0), (0.018, 0.0), (0.02, 0.05), (0.012, 0.07), (0.0, 0.07)], (x, 0.765, -0.28), mat("shaker_%d" % k, c, rough=0.4), seg=12, name="shaker")
    lathe([(0.0, 0.0), (0.028, 0.0), (0.03, 0.12), (0.01, 0.16), (0.008, 0.2), (0.0, 0.2)], (0.0, 0.765, -0.29), mat("oil_glass", "#9a8a2a", rough=0.1, alpha=0.75), seg=12, name="oil")
    lathe([(0.0, 0.0), (0.03, 0.0), (0.035, 0.06), (0.018, 0.1), (0.0, 0.1)], (0.1, 0.765, -0.28), mat("vase", "#2f6aa8", rough=0.3), seg=12, name="vase")
    tube([(0.1, 0.84, -0.28), (0.11, 0.95, -0.27)], 0.003, mat("stem", "#3f6b35", rough=0.7), name="stem")
    sphere(0.02, (0.11, 0.96, -0.27), mat("flower", "#e8553c", rough=0.6), seg=8, rings=6, name="flower")
    # four chairs, each facing the table
    seat = oak()
    for a in range(4):
        ang = a * math.pi / 2
        ux, uz = math.cos(ang), math.sin(ang)        # from the table out to the chair
        cx, cz = ux * 0.62, uz * 0.62
        yaw = -math.degrees(ang) + 90                 # the chair's back on the far side
        parts = []
        parts.append(box((0.4, 0.03, 0.4), (0, 0.45, 0), seat, bevel=0.008, name="seat"))
        for (lx, lz) in [(-0.17, -0.17), (0.17, -0.17), (-0.17, 0.17), (0.17, 0.17)]:
            parts.append(cyl(0.014, 0.44, (lx, 0.22, lz), iron, seg=8, name="chair_leg"))
        for lx in (-0.17, 0.17):
            parts.append(cyl(0.013, 0.42, (lx, 0.66, 0.19), iron, seg=8, rot=(-6, 0, 0), name="chair_back_post"))
        parts.append(box((0.38, 0.09, 0.025), (0, 0.84, 0.2), seat, bevel=0.008, rot=(-6, 0, 0), name="chair_back"))
        ch = join(parts, "chair")
        ch.data.transform(Matrix.Translation(Vector((cx, 0, cz))) @ Matrix.Rotation(math.radians(yaw), 4, "Y"))


@model("mouse")
def mouse():
    """a mouse, nose toward +X"""
    fur = mat("fur", "#77706a", rough=0.9)
    pink = mat("pink", "#e0a0a0", rough=0.7)
    blobs([("ellipsoid", (0, 0.03, 0), 0.04, (1.4, 0.75, 0.85)), ("ellipsoid", (0.045, 0.028, 0), 0.025, (1.3, 0.85, 0.85))], fur, res=0.006, name="body", tris=300)
    for z in (-0.014, 0.014):
        sphere(0.012, (0.04, 0.05, z), pink, seg=10, rings=6, scale=(0.4, 1.0, 1.0), name="ear")
        sphere(0.004, (0.064, 0.038, z * 0.93), black(), seg=8, rings=5, name="eye")
    sphere(0.005, (0.082, 0.026, 0), pink, seg=8, rings=5, name="nose")
    tube([(-0.05, 0.025, 0), (-0.08, 0.012, 0.01), (-0.11, 0.008, -0.01), (-0.14, 0.012, 0.01)], 0.003, pink, name="tail")
