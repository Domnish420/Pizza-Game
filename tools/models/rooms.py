"""The rooms and what is outside them: the van, the restaurant kitchen, the street, the dining room.
All in room coordinates: you stand at the origin facing -Z, eyes at 1.62 m, the floor at y = 0."""
from lib import *
from common import *

G = -0.42      # the street is this far below the van floor


def _canopy():
    """the extraction hood over the oven"""
    hood = slab([(1.65, 1.92), (1.65, 2.25), (0.95, 2.25), (0.95, 2.06), (1.04, 1.92)], 1.32, (0, 0, -0.37), steel(), name="hood")
    box((0.52, 0.012, 1.14), (1.36, 1.915, 0.29), mat("filter", "#6d7376", rough=0.5, metal=0.6), name="filters")
    for i in range(5):
        box((0.52, 0.004, 0.012), (1.36, 1.908, -0.2 + i * 0.24), steel_dark(), name="filter_bar")


def _clock(pos):
    face = mat("clock_face", "#fbfaf6", rough=0.6)
    cyl(0.16, 0.03, pos, black(), axis="z", seg=32, bevel=0.008, name="clock_rim")
    cyl(0.145, 0.006, (pos[0], pos[1], pos[2] - 0.016), face, axis="z", seg=32, name="clock_face")
    for i in range(12):
        a = i * math.pi / 6
        L = 0.03 if i % 3 == 0 else 0.016
        box((0.008, L, 0.003), (pos[0] + math.sin(a) * 0.12, pos[1] + math.cos(a) * 0.12, pos[2] - 0.02), black(), rot=(0, 0, -math.degrees(a)), name="tick")
    box((0.01, 0.08, 0.003), (pos[0] + 0.02, pos[1] + 0.03, pos[2] - 0.023), black(), rot=(0, 0, -35), name="hand_h")
    box((0.006, 0.11, 0.003), (pos[0] - 0.03, pos[1] + 0.04, pos[2] - 0.025), black(), rot=(0, 0, 40), name="hand_m")


def _extinguisher(pos):
    x, y, z = pos
    cyl(0.07, 0.42, (x, y + 0.21, z), red(), seg=20, bevel=0.03, name="ext")
    cyl(0.025, 0.06, (x, y + 0.45, z), black(), name="ext_valve")
    tube([(x, y + 0.47, z), (x + 0.06, y + 0.46, z - 0.02), (x + 0.08, y + 0.3, z - 0.06)], 0.009, black(), name="ext_hose")
    box((0.1, 0.05, 0.02), (x, y + 0.25, z + 0.075), steel_dark(), name="ext_bracket")


@model("room.van", dine=False)
@model("room.kitchen", dine=True)
def room(dine):
    if dine:
        wall = mat("subway", "#ffffff", rough=0.22, tex="subway", normal="subway", uvs=0.6)
        floor_m = mat("quarry", "#ffffff", rough=0.55, tex="quarry", normal="quarry", uvs=0.6)
    else:
        wall = mat("cladding", "#f7f1e6", rough=0.45)
        floor_m = mat("checker", "#ffffff", rough=0.5, tex="checker", uvs=0.6)          # red and cream pizzeria tiles
    ceil = mat("ceiling", "#f3f3f0", rough=0.75)
    alu = mat("alu", "#c4c9cc", rough=0.3, metal=0.7)
    paint = mat("van_paint", TOMATO, rough=0.4)
    # floor and ceiling
    box((3.32, 0.06, 2.48), (0, -0.03, 0.08), floor_m, name="floor")
    box((3.32, 0.04, 2.48), (0, 2.27, 0.08), ceil, name="ceiling")
    # right and back walls
    box((0.04, 2.25, 2.48), (1.64, 1.125, 0.08), wall, name="wall_r")
    box((3.32, 2.25, 0.04), (0, 1.125, 1.3), wall, name="wall_back")
    # left wall, with the back door in it (z 0.35..1.15)
    box((0.04, 2.25, 1.5), (-1.64, 1.125, -0.4), wall, name="wall_l1")
    box((0.04, 2.25, 0.17), (-1.64, 1.125, 1.235), wall, name="wall_l2")
    box((0.04, 0.25, 0.8), (-1.64, 2.125, 0.75), wall, name="wall_l3")
    door_m = mat("door", "#d9dcd8" if not dine else "#7d8a86", rough=0.4, metal=0.3)
    box((0.04, 1.98, 0.78), (-1.665, 0.99, 0.75), door_m, bevel=0.01, name="door")
    for (y, h) in [(1.0, 0.04)]:
        pass
    for side in (-1, 1):
        box((0.03, 2.02, 0.03), (-1.615, 1.0, 0.75 + side * 0.405), alu, name="door_frame")
    box((0.03, 0.03, 0.84), (-1.615, 2.0, 0.75), alu, name="door_frame_top")
    if dine:
        box((0.04, 0.05, 0.6), (-1.6, 1.05, 0.75), chrome(), bevel=0.01, name="push_bar")           # a fire door's push bar
        for side in (-1, 1): box((0.06, 0.08, 0.04), (-1.62, 1.05, 0.75 + side * 0.3), steel_dark(), name="push_bar_end")
        box((0.01, 0.12, 0.3), (-1.635, 1.65, 0.75), mat("sign_green", "#2e9a4c", rough=0.4), name="fire_exit")
    else:
        box((0.012, 0.5, 0.42), (-1.64, 1.55, 0.75), mat("door_glass", "#bcd7e6", rough=0.1, emit="#cfe4f2", emit_k=0.8), name="door_window")
        box((0.03, 0.03, 0.14), (-1.6, 1.0, 1.02), chrome(), bevel=0.008, name="door_handle")
        box((0.03, 0.06, 0.04), (-1.62, 1.0, 1.08), chrome(), name="door_handle_base")
    # the front wall
    if dine:
        # the pass: open above the counters, a stainless-trimmed header above, a low wall below
        box((3.32, 0.28, 0.06), (0, 2.11, -1.12), wall, name="header")
        box((3.32, 0.05, 0.08), (0, 1.97, -1.12), steel(), name="header_trim")
        box((3.32, 0.9, 0.06), (0, 0.45, -1.13), wall, name="low_wall")
    else:
        # the van's hatch: x -0.8..0.8, y 1.05..1.85; cladding inside, the van's paint outside
        for (sx, sy, cx, cy) in [(3.32, 1.05, 0, 0.525), (3.32, 0.4, 0, 2.05), (0.85, 0.8, -1.225, 1.45), (0.85, 0.8, 1.225, 1.45)]:
            box((sx, sy, 0.03), (cx, cy, -1.1), wall, name="front_in")
            box((sx, sy, 0.03), (cx, cy, -1.13), paint, name="front_out")
        # the van body below the floor, seen from the street
        box((3.32, 0.42, 0.03), (0, -0.21, -1.13), paint, name="skirt")
        box((3.32, 0.06, 0.04), (0, -0.4, -1.14), black(), name="skirt_trim")
        # the hatch's aluminium frame and the serving ledge outside
        box((1.66, 0.03, 0.08), (0, 1.04, -1.12), alu, name="hatch_sill")
        box((1.66, 0.03, 0.08), (0, 1.865, -1.12), alu, name="hatch_head")
        for side in (-1, 1): box((0.03, 0.85, 0.08), (side * 0.815, 1.45, -1.12), alu, name="hatch_jamb")
        box((1.7, 0.035, 0.26), (0, 1.05, -1.27), steel(), bevel=0.006, name="ledge")
        for side in (-1, 1):
            box((0.03, 0.18, 0.03), (side * 0.7, 0.95, -1.2), steel_dark(), rot=(-45, 0, 0), name="ledge_bracket")
        # the hatch door, propped up outside as an awning, on gas struts
        ang = 22
        L = 0.9
        cz = -1.15 - math.cos(math.radians(ang)) * L / 2
        cy = 1.9 + math.sin(math.radians(ang)) * L / 2
        box((1.78, 0.025, L), (0, cy + 0.012, cz), paint, rot=(ang, 0, 0), bevel=0.006, name="awning_top")
        box((1.74, 0.012, L - 0.04), (0, cy - 0.008, cz), mat("awning_under", "#f1efe9", rough=0.5), rot=(ang, 0, 0), name="awning_under")
        for side in (-1, 1):
            tube([(side * 0.82, 1.55, -1.16), (side * 0.82, 1.95, -1.6)], 0.012, chrome(), name="strut")
        # a run of lights under the awning's edge
        box((1.6, 0.02, 0.03), (0, 1.9 + math.sin(math.radians(ang)) * L - 0.02, -1.15 - math.cos(math.radians(ang)) * L + 0.03), emit_warm(), name="awning_lights")
        # coving along the floor
        for (sx, sz, cx, cz2) in [(0.02, 2.4, 1.61, 0.08), (3.25, 0.02, 0, 1.27)]:
            box((sx, 0.08, sz), (cx, 0.04, cz2), alu, name="coving")
    # the ceiling: lights, and a roof vent in the van
    if dine:
        for x in (-0.7, 0.4):
            box((0.16, 0.06, 1.3), (x, 2.22, 0.1), white(), bevel=0.01, name="light_box")
            box((0.12, 0.01, 1.24), (x, 2.19, 0.1), emit_cool(), name="light_diffuser")
    else:
        for x in (-0.55, 0.45):
            box((0.05, 0.015, 2.0), (x, 2.245, 0.05), emit_cool(), name="led_strip")
        box((0.42, 0.04, 0.42), (-0.1, 2.235, 0.55), white(), bevel=0.01, name="roof_vent")
        for i in range(6): box((0.38, 0.006, 0.012), (-0.1, 2.213, 0.38 + i * 0.065), mat("vent_slot", "#9aa0a3", rough=0.5), name="vent_slot")
    _canopy()
    # a band of colour round the walls, just above the counters
    band = mat("band", TOMATO if not dine else BASIL, rough=0.45)
    for (sx, sz, cx, cz) in [(3.24, 0.012, 0, 1.274), (0.012, 2.4, 1.614, 0.08), (0.012, 1.48, -1.614, -0.4), (0.012, 0.15, -1.614, 1.22)]:
        box((sx, 0.07, sz), (cx, 1.06, cz), band, bevel=0, name="band")
    # on the back wall: a clock, the fuse box, a paper towel dispenser, a fire extinguisher
    _clock((-0.16, 1.98, 1.28))
    box((0.3, 0.36, 0.1), (-1.25, 1.92, 1.25), mat("fusebox", "#e6e6e2", rough=0.5), bevel=0.01, name="fusebox")
    box((0.26, 0.3, 0.12), (-0.16, 1.45, 1.22), white(), bevel=0.02, name="towels")
    box((0.18, 0.02, 0.01), (-0.16, 1.32, 1.16), mat("towel_paper", "#fbfbf8", rough=0.9), name="towel_end")
    _extinguisher((-1.5, 0.55, 1.2))


# ---------------------------------------------------------------- the street outside the van and kiosk

SHOPS = [("CAFE", "#3d6b4f"), ("BAKERY", "#8a4b2f"), ("BOOKS", "#2f4a6b"), ("FLOWERS", "#7a3d63"), ("NEWS", "#6b5a2f"),
         ("BARBER", "#2a2a2a"), ("DELI", "#4f6b2f")]


def _tree(x, z, h=3.2):
    trunk = mat("bark", "#5b4330", rough=0.9)
    tube([(x, G, z), (x + 0.05, G + h * 0.5, z), (x - 0.03, G + h * 0.75, z)], 0.08, trunk, radii=[0.1, 0.07, 0.05], name="trunk")
    leaves = mat("leaves", "#4f7a3a", rough=0.85)
    els = []
    import random
    rnd = random.Random(int(x * 10 + z))
    for i in range(9):
        els.append(("ball", (x + rnd.uniform(-0.8, 0.8), G + h * 0.75 + rnd.uniform(-0.3, 0.7), z + rnd.uniform(-0.6, 0.6)), rnd.uniform(0.55, 0.8)))
    blobs(els, leaves, res=0.12, name="leaves", tris=500)


@model("street")
def street():
    ROUND[0] = False                  # far away: plain boxes keep it cheap
    slabs = mat("slabs", "#ffffff", rough=0.8, tex="slabs", normal="slabs", uvs=1.2)
    road = mat("asphalt", "#ffffff", rough=0.9, tex="asphalt", uvs=3.0)
    stone = mat("kerb", "#b0aba2", rough=0.8, tex="stone", uvs=0.8)
    line_w = mat("line_white", "#eeeeea", rough=0.7)
    line_y = mat("line_yellow", "#e2b93b", rough=0.7)
    # near pavement (under and in front of the van), the kerb, the road, the far kerb and pavement
    box((44, 0.3, 7.2), (0, G - 0.15, -2.05), slabs, name="pavement")
    box((44, 0.18, 0.16), (0, G - 0.09, -5.73), stone, name="kerb")
    box((44, 0.3, 9.0), (0, G - 0.27, -10.3), road, name="road")
    box((44, 0.18, 0.16), (0, G - 0.09, -14.86), stone, name="kerb_far")
    box((44, 0.3, 1.0), (0, G - 0.15, -15.4), slabs, name="pavement_far")
    for i in range(-7, 8):
        box((1.6, 0.006, 0.12), (i * 3.2, G - 0.117, -10.3), line_w, name="centre_line")
    for z in (-5.92, -6.06):
        box((44, 0.006, 0.08), (0, G - 0.117, z), line_y, name="yellow_line")
    # the shops across the road
    heights = [5, 7, 9, 6, 8, 5, 7]
    facades = [mat("brick", "#ffffff", rough=0.85, tex="brick", normal="brick", uvs=1.6),
               mat("brick_y", "#ffffff", rough=0.85, tex="brick_yellow", normal="brick_yellow", uvs=1.6),
               mat("render_blue", "#7a8aa0", rough=0.8), mat("render_cream", "#d8c39a", rough=0.8),
               mat("render_sage", "#8a9a7a", rough=0.8), mat("render_tan", "#c9a27a", rough=0.8)]
    shop_glass = mat("shop_glass", "#2b2620", rough=0.1, metal=0.2, emit="#ffcf8a", emit_k=0.5)
    win_glass = mat("win_glass", "#3b4a55", rough=0.08, metal=0.3)
    frame = mat("frame", "#f2efe6", rough=0.5)
    sign_text = mat("sign_text", "#f4ead2", rough=0.4)
    door_m = mat("shop_door", "#3a2e24", rough=0.5)
    for i in range(7):
        cx = -17.1 + i * 5.7
        h = heights[i]
        front = -15.9
        fac = facades[[0, 3, 1, 2, 0, 4, 5][i]]
        box((5.6, h, 3.0), (cx, G + h / 2, front - 1.5), fac, name="building")
        box((5.8, 0.25, 3.2), (cx, G + h + 0.05, front - 1.5), frame, bevel=0.02, name="cornice")
        name, col = SHOPS[i]
        shopfront = mat("shopfront_%d" % i, col, rough=0.45)
        # the shop: fascia, window, door, maybe an awning
        box((5.4, 0.6, 0.12), (cx, G + 2.75, front + 0.06), shopfront, bevel=0.02, name="fascia")
        text(name, (cx, G + 2.75, front + 0.125), sign_text, size=0.36, depth=0.01, name="shop_name")
        box((5.4, 2.4, 0.1), (cx, G + 1.25, front + 0.04), shopfront, name="shop_surround")
        box((3.4, 1.7, 0.04), (cx - 0.7, G + 1.35, front + 0.1), shop_glass, name="shop_window")
        box((0.95, 2.1, 0.05), (cx + 1.85, G + 1.05, front + 0.1), door_m, bevel=0.01, name="shop_door")
        box((0.6, 0.9, 0.02), (cx + 1.85, G + 1.45, front + 0.13), shop_glass, name="door_glass")
        if i % 2 == 0:
            stripe = mat("awning_%d" % i, ["#c0392b", "#2e7d5b", "#d4a72c", "#2f5d8a"][i // 2], rough=0.6)
            box((4.6, 0.03, 1.1), (cx - 0.3, G + 2.32, front + 0.55), stripe, rot=(-18, 0, 0), name="awning")
            box((4.6, 0.25, 0.02), (cx - 0.3, G + 2.05, front + 1.06), stripe, name="awning_valance")
        # upper floors
        floors = int((h - 3.2) // 2.6) + 1
        for f in range(floors):
            y = G + 3.4 + f * 2.6
            if y + 1.4 > G + h - 0.2: break
            for k in range(3):
                wx = cx - 1.8 + k * 1.8
                box((1.1, 1.5, 0.08), (wx, y + 0.75, front + 0.02), frame, name="win_frame")
                box((0.92, 1.32, 0.04), (wx, y + 0.75, front + 0.06), win_glass, name="win")
                box((0.04, 1.32, 0.03), (wx, y + 0.75, front + 0.08), frame, name="win_bar")
                box((1.25, 0.06, 0.18), (wx, y - 0.02, front + 0.1), frame, name="sill")
        # chimneys on the roof, window boxes of flowers on the first floor
        for cxo in (-1.6, 1.9):
            box((0.5, 0.9, 0.5), (cx + cxo, G + h + 0.6, front - 2.2), fac, name="chimney")
            for k in range(2):
                cyl(0.08, 0.3, (cx + cxo - 0.1 + k * 0.2, G + h + 1.2, front - 2.2), mat("pot_clay", TERRACOTTA, rough=0.7), seg=10, name="chimney_pot")
        if h >= 6:
            flowers = mat("flowers_%d" % (i % 3), ["#e8553c", "#f4c64f", "#c86bd9"][i % 3], rough=0.6)
            for k in range(3):
                wx = cx - 1.8 + k * 1.8
                box((1.0, 0.18, 0.22), (wx, G + 3.4 + 0.07, front + 0.3), mat("planter", "#5a4030", rough=0.7), name="window_box")
                blobs([("ball", (wx + (j - 2) * 0.2, G + 3.62, front + 0.3), 0.11) for j in range(5)], flowers, res=0.05, name="blooms", tris=60)
    # a parked car across the road
    car = mat("car", "#2f8ad9", rough=0.35)
    glass_c = mat("car_glass", "#26333b", rough=0.15)
    tyre = mat("tyre", "#222426", rough=0.8)
    cxp, czp = 3.2, -13.6
    box((3.9, 0.7, 1.75), (cxp, G - 0.12 + 0.62, czp), car, bevel=0.15, name="car_body")
    box((2.2, 0.55, 1.6), (cxp - 0.2, G - 0.12 + 1.22, czp), car, bevel=0.18, name="car_cabin")
    box((2.0, 0.42, 1.62), (cxp - 0.2, G - 0.12 + 1.24, czp), glass_c, bevel=0.12, name="car_windows")
    for (wx, wz) in [(-1.25, -0.82), (1.25, -0.82), (-1.25, 0.82), (1.25, 0.82)]:
        cyl(0.34, 0.24, (cxp + wx, G - 0.12 + 0.34, czp + wz), tyre, axis="z", seg=18, name="wheel")
        cyl(0.18, 0.25, (cxp + wx, G - 0.12 + 0.34, czp + wz), chrome(), axis="z", seg=14, name="hubcap")
    for sx in (-1, 1):
        sphere(0.09, (cxp + sx * 1.94, G - 0.12 + 0.72, czp - 0.62), mat("car_light_%d" % sx, "#fff4c8" if sx < 0 else TOMATO, rough=0.3), seg=10, rings=6, scale=(0.4, 1, 1), name="car_light")
        sphere(0.09, (cxp + sx * 1.94, G - 0.12 + 0.72, czp + 0.62), mat("car_light_%d" % sx, "#fff4c8" if sx < 0 else TOMATO, rough=0.3), seg=10, rings=6, scale=(0.4, 1, 1), name="car_light")
    # on our side: a lamp post, a bench, a bin, bollards and two trees
    post = mat("post", "#22282b", rough=0.4, metal=0.5)
    lx, lz = 2.6, -2.6
    cyl(0.12, 0.35, (lx, G + 0.175, lz), post, seg=12, bevel=0.03, name="post_base")
    cyl(0.055, 3.4, (lx, G + 1.9, lz), post, seg=12, r2=0.04, name="post")
    box((0.3, 0.4, 0.3), (lx, G + 3.75, lz), post, bevel=0.02, name="lantern_frame")
    box((0.24, 0.32, 0.24), (lx, G + 3.75, lz), mat("lantern", "#ffe6b0", rough=0.3, emit="#ffd58a", emit_k=1.5), name="lantern")
    cyl(0.2, 0.08, (lx, G + 3.98, lz), post, r2=0.06, seg=12, name="lantern_cap")
    bx, bz = -3.6, -4.9
    seat = oak()
    for k in range(3):
        box((1.6, 0.03, 0.09), (bx, G + 0.45, bz - 0.12 + k * 0.11), seat, bevel=0.008, name="bench_slat")
    for k in range(2):
        box((1.6, 0.09, 0.03), (bx, G + 0.62 + k * 0.13, bz + 0.15), seat, rot=(-12, 0, 0), bevel=0.008, name="bench_back")
    for sx in (-0.7, 0.7):
        box((0.05, 0.45, 0.4), (bx + sx, G + 0.225, bz), post, name="bench_leg")
        box((0.05, 0.35, 0.05), (bx + sx, G + 0.62, bz + 0.17), post, rot=(-12, 0, 0), name="bench_arm")
    cyl(0.22, 0.85, (4.2, G + 0.425, -5.1), mat("bin_green", "#2f4f3a", rough=0.5), seg=16, bevel=0.03, name="litter_bin")
    cyl(0.24, 0.05, (4.2, G + 0.875, -5.1), post, seg=16, name="bin_lid")
    for x in (-1.6, -0.6, 1.4):
        cyl(0.06, 0.8, (x, G + 0.4, -5.4), post, seg=10, bevel=0.03, name="bollard")
    _tree(-6.5, -4.6)
    _tree(7.0, -4.6)


# ---------------------------------------------------------------- the dining room (shops and up)

@model("dining")
def dining():
    ROUND[0] = False
    floor_m = mat("planks", "#ffffff", rough=0.55, tex="planks", normal="planks", uvs=2.0)
    plaster = mat("plaster", "#ffffff", rough=0.85, tex="plaster", uvs=2.0)
    panel = mat("wainscot", "#3f7a55", rough=0.5)
    beam = walnut()
    x0, x1, z0, z1, H = -5.2, 4.2, -14.1, -1.12, 3.0
    cx, cz, W, D = (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0
    box((W, 0.1, D), (cx, -0.05, cz), floor_m, name="floor")
    box((W, 0.1, D), (cx, H + 0.05, cz), mat("ceiling", "#f3efe6", rough=0.8), name="ceiling")
    # walls: plaster above, painted panelling below, with a dado rail
    walls = [((0.1, H, D), (x0 - 0.05, H / 2, cz), "x"), ((0.1, H, D), (x1 + 0.05, H / 2, cz), "x"), ((W, H, 0.1), (cx, H / 2, z0 - 0.05), "z")]
    for (s, p, ax) in walls:
        box(s, p, plaster, name="wall")
        if ax == "x":
            inset = 0.02 if p[0] > 0 else -0.02
            box((0.04, 1.0, D), (p[0] - (0.05 + inset) * (1 if p[0] > 0 else -1), 0.5, cz), panel, name="wainscot")
            box((0.06, 0.05, D), (p[0] - 0.08 * (1 if p[0] > 0 else -1), 1.02, cz), beam, name="dado")
        else:
            box((W, 1.0, 0.04), (cx, 0.5, z0 + 0.03), panel, name="wainscot")
            box((W, 0.05, 0.06), (cx, 1.02, z0 + 0.05), beam, name="dado")
    # the near wall, round the kitchen's pass (the kitchen is x -1.65..1.65)
    box((x0 + 1.65 - 0.0, H, 0.1), ((x0 - 1.65) / 2, H / 2, z1 - 0.05), plaster, name="near_wall_l")
    box((x1 - 1.65, H, 0.1), ((x1 + 1.65) / 2, H / 2, z1 - 0.05), plaster, name="near_wall_r")
    box((3.3, H - 2.25, 0.1), (0, (H + 2.25) / 2, z1 - 0.05), plaster, name="near_wall_top")
    for x in (-1.68, 1.68):
        box((0.08, H, 0.14), (x, H / 2, z1 - 0.05), beam, name="pass_post")
    # beams across the ceiling
    for k in range(5):
        box((W, 0.22, 0.18), (cx, H - 0.11, -2.6 - k * 2.6), beam, name="beam")
    # the far wall: tall windows and the glass front door
    sky = mat("window_sky", "#d6e7f0", rough=0.2, emit="#d8ecf7", emit_k=0.9)
    frame = mat("window_frame", "#262a2c", rough=0.4, metal=0.4)
    for wx in (-3.6, -1.2, 1.2):
        box((1.7, 2.1, 0.06), (wx, 1.65, z0 + 0.02), frame, name="win_frame")
        box((1.56, 1.96, 0.04), (wx, 1.65, z0 + 0.05), sky, name="win")
        box((0.04, 1.96, 0.05), (wx, 1.65, z0 + 0.07), frame, name="win_mullion")
        box((1.56, 0.04, 0.05), (wx, 2.1, z0 + 0.07), frame, name="win_transom")
    box((1.1, 2.3, 0.08), (3.3, 1.15, z0 + 0.04), frame, name="door_frame")
    box((0.96, 2.16, 0.04), (3.3, 1.15, z0 + 0.08), sky, name="door_glass")
    box((0.04, 0.5, 0.05), (3.0, 1.1, z0 + 0.12), chrome(), name="door_handle")
    # pictures on the side walls
    import random
    rnd = random.Random(7)
    canv = ["#c86b3c", "#3c6bc8", "#d9b23f", "#3f9a6b", "#b53a4a", "#e6dcc8", "#2b3a4a"]
    for side, xw in ((-1, x0 + 0.03), (1, x1 - 0.03)):
        for k in range(4):
            z = -3.0 - k * 2.9
            w, h = rnd.choice([(0.9, 0.7), (0.7, 0.9), (1.1, 0.8)])
            box((0.04, h + 0.08, w + 0.08), (xw, 1.75, z), beam, bevel=0.01, name="pic_frame")
            a, b = rnd.sample(canv, 2)
            box((0.02, h, w), (xw - side * 0.025, 1.75, z), mat("canvas_" + a, a, rough=0.8), name="pic")
            box((0.022, h * 0.45, w * 0.6), (xw - side * 0.03, 1.75 - h * 0.12, z + w * 0.1), mat("canvas_" + b, b, rough=0.8), name="pic_shape")
    # pendant lamps (the three that light the room are lights in the game too)
    shade = mat("shade", "#1f2a24", rough=0.35, metal=0.5)
    brass = mat("brass", "#b8913a", rough=0.3, metal=0.8)
    for (px, pz) in [(-1.5, -4.0), (0.5, -7.0), (2.5, -10.0), (-3.4, -6.0), (2.2, -3.6), (-2.0, -11.5), (-0.6, -9.0)]:
        tube([(px, H, pz), (px, 2.5, pz)], 0.006, black(), name="wire")
        lathe([(0.0, 2.55), (0.04, 2.55), (0.06, 2.5), (0.2, 2.34), (0.22, 2.32), (0.0, 2.32)], (px, 0, pz), shade, seg=20, name="shade")
        cyl(0.03, 0.04, (px, 2.53, pz), brass, seg=12, name="lamp_cap")
        sphere(0.05, (px, 2.33, pz), emit_warm(), seg=12, rings=8, name="bulb")
    # red leather banquettes along both side walls (the game's tables stand clear of them, x -3.3..2.3)
    leather = mat("leather", "#b8402e", rough=0.45)
    base_w = walnut()
    for side, xw in ((-1, x0), (1, x1)):
        xs = xw - side * 0.25                       # the seat's middle, 0.5 deep from the wall
        box((0.5, 0.36, 10.4), (xs, 0.18, -7.6), base_w, name="banquette_base")
        box((0.5, 0.1, 10.4), (xs, 0.41, -7.6), leather, name="banquette_seat")
        for k in range(8):                           # the back, in buttoned panels
            box((0.12, 0.52, 1.24), (xw - side * 0.06, 0.73, -3.02 - k * 1.3), leather, name="banquette_back")
        box((0.14, 0.05, 10.4), (xw - side * 0.07, 1.015, -7.6), base_w, name="banquette_cap")
    # plants in the corners, and a shelf of bottles on the right wall
    pot = mat("terracotta", "#b5603b", rough=0.8)
    leaves = mat("plant", "#3f6b35", rough=0.8)
    for (px, pz) in [(-4.75, -13.6), (3.75, -13.6), (-4.75, -1.65), (3.75, -1.65)]:
        lathe([(0.0, 0.0), (0.16, 0.0), (0.22, 0.45), (0.24, 0.47), (0.2, 0.47), (0.0, 0.42)], (px, 0, pz), pot, seg=16, name="pot")
        rp = random.Random(int(px * 100 + pz))
        blobs([("ball", (px + rp.uniform(-0.2, 0.2), 0.75 + rp.uniform(0, 0.9), pz + rp.uniform(-0.2, 0.2)), rp.uniform(0.22, 0.32)) for _ in range(8)], leaves, res=0.06, name="foliage", tris=260)
    box((0.22, 0.03, 2.4), (x1 - 0.12, 1.6, -6.0), beam, bevel=0.01, name="shelf")
    bottle_cols = ["#2f5a2f", "#5a2f1f", "#2f3f5a", "#7a6a2f"]
    for k in range(10):
        bm_ = mat("bottle_" + bottle_cols[k % 4], bottle_cols[k % 4], rough=0.1, metal=0.1)
        lathe([(0.0, 0.0), (0.037, 0.0), (0.04, 0.02), (0.04, 0.2), (0.016, 0.26), (0.013, 0.32), (0.0, 0.32)], (x1 - 0.12, 1.615, -7.0 + k * 0.22), bm_, seg=12, name="bottle")
