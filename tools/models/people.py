"""People: six customers, the delivery-app rider, and your own forearms and hands.

Customers stand 1.75 m tall facing +Z. Each leg hangs from a named joint (hip_l / hip_r, with knee_l / knee_r
below), so the game can bend them to sit a customer down at a table. The hands point forward (-Z) with the
fingertips at the origin, for the camera to carry."""
from lib import *
from common import *

SKIN = ["#f1c6a5", "#c98f65", "#8d5a3b", "#e8b48f", "#5e3a26", "#f4d0b5"]
LOOKS = [
    dict(skin=0, hair="short", hair_col="#3b2a1e", shirt="#c0392b", sleeves="short", legs="#2c3e50", shoes="#222222"),
    dict(skin=1, hair="bun", hair_col="#1d1a18", shirt="#2e86c1", sleeves="long", legs="#3b3b3b", shoes="#5a3a22"),
    dict(skin=2, hair="curly", hair_col="#141210", shirt="#f1c40f", sleeves="short", legs="#4a5a2a", shoes="#e8e8e8"),
    dict(skin=3, hair="long", hair_col="#c9a25a", shirt="#8e44ad", sleeves="long", legs="#2a2a3a", shoes="#2a2a2a"),
    dict(skin=4, hair="beard", hair_col="#1a1612", shirt="#27ae60", sleeves="short", legs="#5a4a3a", shoes="#3a2a1a"),
    dict(skin=5, hair="cap", hair_col="#6b4a2a", shirt="#e67e22", sleeves="long", legs="#34495e", shoes="#c0392b", cap="#2f5d8a"),
]
HIP_Y, KNEE_Y, LEG_X = 0.92, 0.5, 0.09


def _leg(side, legs_m, shoe_m):
    """one leg hanging from its hip joint, bending at the knee"""
    tag = "l" if side > 0 else "r"
    x = side * LEG_X
    hip = empty("hip_" + tag, (x, HIP_Y, 0))
    knee = empty("knee_" + tag, (0, KNEE_Y - HIP_Y, 0), parent=hip)
    thigh = blobs([("capsule", (x, (HIP_Y + KNEE_Y) / 2, 0), 0.072, (HIP_Y - KNEE_Y) / 2, (0, 0, 90))], legs_m, res=0.02, name="thigh_" + tag, tris=160)
    thigh.data.transform(Matrix.Translation(Vector((-x, -HIP_Y, 0))))
    thigh.parent = hip
    shin = blobs([("capsule", (x, (KNEE_Y + 0.1) / 2, 0), 0.056, (KNEE_Y - 0.1) / 2, (0, 0, 90))], legs_m, res=0.02, name="shin_" + tag, tris=140)
    shoe = blobs([("ellipsoid", (x, 0.045, 0.035), 0.06, (0.8, 0.62, 1.55))], shoe_m, res=0.015, name="shoe_" + tag, tris=90)
    lower = join([shin, shoe], "lower_" + tag)
    lower.data.transform(Matrix.Translation(Vector((-x, -KNEE_Y, 0))))
    lower.parent = knee


def _hair(look, hm, skin_m):
    h = look["hair"]
    if h in ("short", "bun", "curly", "long", "cap"):
        blobs([("ellipsoid", (0, 1.675, -0.012), 0.112, (0.97, 0.82, 1.02))], hm, res=0.012, name="hair", tris=260)
    if h == "bun":
        blobs([("ball", (0, 1.72, -0.11), 0.05)], hm, res=0.01, name="bun", tris=80)
    if h == "curly":
        els = []
        for i in range(14):
            a = i * 2.4
            els.append(("ball", (math.cos(a) * 0.08, 1.7 + math.sin(i * 1.3) * 0.03, -0.01 + math.sin(a) * 0.08), 0.045))
        blobs(els, hm, res=0.012, name="curls", tris=420)
    if h == "long":
        blobs([("ellipsoid", (0, 1.52, -0.075), 0.1, (1.05, 1.7, 0.55))], hm, res=0.014, name="long_hair", tris=200)
    if h == "beard":
        blobs([("ellipsoid", (0, 1.565, 0.05), 0.07, (1.05, 0.75, 0.8)), ("ellipsoid", (0, 1.69, -0.02), 0.1, (0.95, 0.5, 0.95))], hm, res=0.012, name="beard", tris=300)
    if h == "cap":
        cm = mat("cap", look["cap"], rough=0.6)
        prof = [(math.cos(math.pi / 2 * i / 8) * 0.112, math.sin(math.pi / 2 * i / 8) * 0.09) for i in range(9)] + [(0.0, 0.0)]
        lathe(prof, (0, 1.68, -0.005), cm, seg=20, name="cap")
        box((0.15, 0.012, 0.09), (0, 1.69, 0.13), cm, bevel=0.004, rot=(-8, 0, 0), name="brim")


def _person(look, rider=False):
    skin_m = mat("skin", SKIN[look["skin"]], rough=0.65)
    shirt_m = mat("shirt", look["shirt"], rough=0.75)
    legs_m = mat("legs", look["legs"], rough=0.8)
    shoe_m = mat("shoes", look["shoes"], rough=0.5)
    hair_m = mat("hair", look["hair_col"], rough=0.8)
    eye_m = mat("eye", "#1a1410", rough=0.3)
    # the body: hips, torso and arms, neck and head
    blobs([("ellipsoid", (0, 0.96, 0), 0.165, (1.0, 0.72, 0.78))], legs_m, res=0.022, name="hips", tris=160)
    torso = [("ellipsoid", (0, 1.27, 0), 0.17, (1.0, 1.22, 0.66)), ("ellipsoid", (0, 1.08, 0), 0.15, (0.95, 0.9, 0.72)),
             ("ellipsoid", (0, 1.385, 0), 0.155, (1.22, 0.42, 0.62))]
    arms, arms_skin = [], []
    for s in (1, -1):
        sh, el, wr = (s * 0.235, 1.375, 0.0), (s * 0.262, 1.12, 0.02), (s * 0.272, 0.885, 0.06)
        arms.append(("capsule", ((sh[0] + el[0]) / 2, (sh[1] + el[1]) / 2, 0.01), 0.048, 0.125, (0, 0, 90 + s * 6)))
        fore = ("capsule", ((el[0] + wr[0]) / 2, (el[1] + wr[1]) / 2, 0.04), 0.04, 0.115, (-10, 0, 90 + s * 2))
        (arms if look["sleeves"] == "long" or rider else arms_skin).append(fore)
        arms_skin.append(("ellipsoid", (wr[0], 0.845, 0.065), 0.042, (0.7, 1.25, 0.9)))
    top_m = mat("jacket", "#2fb39a", rough=0.6) if rider else shirt_m
    blobs(torso, top_m, res=0.022, name="torso", tris=600)
    blobs(arms, top_m, res=0.014, name="arms", tris=360)
    head = [("capsule", (0, 1.49, 0), 0.048, 0.04, (0, 0, 90)), ("ellipsoid", (0, 1.63, 0.0), 0.105, (0.9, 1.15, 1.0))] + arms_skin
    blobs(head, skin_m, res=0.011, name="skin", tris=900)
    sphere(0.019, (0, 1.615, 0.1), skin_m, seg=10, rings=6, name="nose")
    for s in (1, -1):
        sphere(0.012, (s * 0.035, 1.652, 0.093), eye_m, seg=10, rings=6, name="eye")
        if not rider:
            box((0.035, 0.008, 0.01), (s * 0.037, 1.676, 0.096), hair_m, rot=(0, 0, s * 6), name="brow")
    box((0.03, 0.006, 0.008), (0, 1.585, 0.097), mat("mouth", "#8a4a3a", rough=0.6), name="mouth")
    if rider:
        helmet = mat("helmet", "#20262a", rough=0.25, metal=0.2)
        prof = [(math.cos(math.pi / 2 * i / 10) * 0.135, math.sin(math.pi / 2 * i / 10) * 0.15) for i in range(11)] + [(0.0, 0.0)]
        lathe(prof, (0, 1.6, -0.01), helmet, seg=22, name="helmet")
        box((0.2, 0.012, 0.03), (0, 1.6, 0.1), helmet, name="helmet_rim")
        # the insulated bag on the back
        bag = mat("bag", "#2fb39a", rough=0.55)
        box((0.4, 0.4, 0.24), (0, 1.22, -0.25), bag, bevel=0.03, name="bag")
        text("RAPIDO", (0, 1.24, -0.372), mat("bag_text", "#ffffff", rough=0.5), size=0.06, depth=0.003, rot=(0, 180, 0), name="bag_text")
        for s in (1, -1):
            tube([(s * 0.12, 1.42, -0.13), (s * 0.13, 1.42, 0.02), (s * 0.12, 1.1, 0.08)], 0.012, black(), name="strap")
    else:
        _hair(look, hair_m, skin_m)
    for s in (1, -1):
        _leg(s, mat("legs_dark", "#1f2326", rough=0.8) if rider else legs_m, shoe_m)


for _i, _look in enumerate(LOOKS):
    model("customer.%d" % _i, look=_look)(_person)
model("rider", look=dict(LOOKS[0], shirt="#2fb39a", legs="#1f2326", shoes="#2a2a2a"), rider=True)(_person)


def _hand(side):
    """forearm and hand, palm down, pointing -Z, fingertips at the origin (side 1 = right hand)"""
    skin = mat("skin", "#e2ad86", rough=0.6)
    s = side
    els = [("ellipsoid", (0.002 * s, 0.0, 0.088), 0.046, (1.0, 0.42, 1.0))]
    fingers = [(-0.028, 0.051, 0.006, 0.0088), (-0.008, 0.053, 0.0, 0.0092), (0.012, 0.052, 0.006, 0.0088), (0.03, 0.058, 0.022, 0.0078)]
    for (fx, z0, z1, r) in fingers:
        a = Vector((fx * s, 0.0, z0)); b = Vector((fx * 1.08 * s, -0.012, z1))
        mid = (a + b) / 2
        d = b - a
        yaw = math.degrees(math.atan2(d.x, d.z))
        pitch = math.degrees(math.atan2(-d.y, math.hypot(d.x, d.z)))
        els.append(("capsule", tuple(mid), r, d.length / 2, (pitch, yaw, 0) if False else (0, yaw + 90, 0)))
    # the thumb, along the inside
    els.append(("capsule", (-0.047 * s, -0.008, 0.075), 0.0115, 0.026, (0, 90 - s * 30, 0)))
    # the wrist and forearm back to the sleeve
    els.append(("capsule", (0.006 * s, 0.006, 0.25), 0.034, 0.12, (0, 90, 0)))
    blobs(els, skin, res=0.0045, name="hand", tris=1600)
    whites = mat("chef_whites", "#f6f6f2", rough=0.8)
    cyl(0.05, 0.14, (0.008 * s, 0.008, 0.4), whites, axis="z", seg=16, name="sleeve")
    torus(0.047, 0.008, (0.008 * s, 0.008, 0.33), whites, seg=16, rseg=6, rot=(90, 0, 0), name="cuff")


model("hand.right", side=1)(_hand)
model("hand.left", side=-1)(_hand)
