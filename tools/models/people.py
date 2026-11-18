"""People: six customers, the delivery-app rider, and your own forearms and hands.

The style is friendly cartoon: a big round head with a simple painted face (big eyes, eyebrows, a smile), a short
chunky body, mitten-like hands and big shoes, about 1.6 m tall, facing +Z. Each leg hangs from a named joint
(hip_l / hip_r, with knee_l / knee_r below), so the game can bend them to sit a customer down at a table. The hands
point forward (-Z) with the fingertips at the origin, for the camera to carry."""
from lib import *
from common import *

SKIN = ["#f6cfae", "#d39a6c", "#8d5a3b", "#efbd96", "#5e3a26", "#f8d9be"]
LOOKS = [
    dict(skin=0, hair="short", hair_col="#5a3a22", shirt=TOMATO, sleeves="short", legs=NAVY, shoes="#33383b"),
    dict(skin=1, hair="bun", hair_col="#2a2220", shirt="#3a8fd9", sleeves="long", legs="#4a4f55", shoes="#8a5a36"),
    dict(skin=2, hair="curly", hair_col="#1c1816", shirt=CHEESE, sleeves="short", legs=OLIVE, shoes="#f2f2ee"),
    dict(skin=3, hair="long", hair_col="#e0b45a", shirt="#9b59b6", sleeves="long", legs="#3a3550", shoes="#33383b"),
    dict(skin=4, hair="beard", hair_col="#241c16", shirt=BASIL, sleeves="short", legs="#7a5a3e", shoes="#5a3a22"),
    dict(skin=5, hair="cap", hair_col="#7a4e2a", shirt="#f08a3c", sleeves="long", legs="#3b5878", shoes=TOMATO, cap="#2f6aa8"),
]
HIP_Y, KNEE_Y, LEG_X = 0.72, 0.40, 0.095            # before growing (GROW below): the hips end up at 0.79
HEAD_Y, HEAD_R = 1.42, 0.16


def _leg(side, legs_m, shoe_m):
    """one leg hanging from its hip joint, bending at the knee, with a big shoe"""
    tag = "l" if side > 0 else "r"
    x = side * LEG_X
    hip = empty("hip_" + tag, (x, HIP_Y, 0))
    knee = empty("knee_" + tag, (0, KNEE_Y - HIP_Y, 0), parent=hip)
    thigh = blobs([("capsule", (x, (HIP_Y + KNEE_Y) / 2, 0), 0.078, (HIP_Y - KNEE_Y) / 2, (0, 0, 90))], legs_m, res=0.02, name="thigh_" + tag, tris=150)
    thigh.data.transform(Matrix.Translation(Vector((-x, -HIP_Y, 0))))
    thigh.parent = hip
    shin = blobs([("capsule", (x, (KNEE_Y + 0.1) / 2, 0), 0.066, (KNEE_Y - 0.1) / 2, (0, 0, 90))], legs_m, res=0.02, name="shin_" + tag, tris=130)
    shoe = blobs([("ellipsoid", (x, 0.05, 0.045), 0.078, (0.92, 0.68, 1.55))], shoe_m, res=0.015, name="shoe_" + tag, tris=110)
    sole = min(v.co.y for v in shoe.data.vertices)
    shoe.data.transform(Matrix.Translation(Vector((0, -sole, 0))))     # the sole exactly on the ground
    lower = join([shin, shoe], "lower_" + tag)
    lower.data.transform(Matrix.Translation(Vector((-x, -KNEE_Y, 0))))
    lower.parent = knee


def _face(hair_m, rider=False):
    """big friendly painted-style eyes, eyebrows and a smile on the front of the head"""
    white_m = mat("eye_white", "#fbfbf8", rough=0.4)
    pupil_m = mat("pupil", "#2a201a", rough=0.3)
    shine_m = mat("shine", "#ffffff", rough=0.2, emit="#ffffff", emit_k=0.6)
    for s in (1, -1):
        ex, ey = s * 0.055, HEAD_Y + 0.035
        ez = HEAD_R * 0.86
        sphere(0.032, (ex, ey, ez), white_m, seg=12, rings=8, scale=(0.85, 1.15, 0.45), name="eye_white")
        sphere(0.019, (ex * 0.96, ey - 0.004, ez + 0.012), pupil_m, seg=10, rings=6, scale=(1.0, 1.15, 0.5), name="pupil")
        sphere(0.006, (ex * 0.96 + 0.006, ey + 0.007, ez + 0.02), shine_m, seg=6, rings=4, name="shine")
        if not rider:
            box((0.052, 0.014, 0.02), (s * 0.058, HEAD_Y + 0.088, HEAD_R * 0.83), hair_m, rot=(-12, 0, s * 8), bevel=0.006, name="brow")
    pts = [(math.sin(a) * 0.042, HEAD_Y - 0.05 - math.cos(a) * 0.016, HEAD_R * 0.9) for a in [-1.0 + i * 0.25 for i in range(9)]]
    tube(pts, 0.0065, mat("mouth", "#7a2e22", rough=0.6), seg=6, name="smile")


def _hair(look, hm):
    h = look["hair"]
    top = (0, HEAD_Y + 0.05, -0.015)
    if h in ("short", "bun", "curly", "long", "beard"):
        sc = (1.03, 0.78, 1.02) if h != "beard" else (1.0, 0.6, 1.0)
        blobs([("ellipsoid", top, HEAD_R * 1.04, sc), ("ellipsoid", (0, HEAD_Y + 0.11, 0.07), 0.08, (1.3, 0.55, 0.7))], hm, res=0.014, name="hair", tris=260)
    if h == "bun":
        sphere(0.07, (0, HEAD_Y + 0.17, -0.11), hm, seg=12, rings=8, name="bun")
    if h == "curly":
        els = []
        for i in range(16):
            a = i * 2.4
            els.append(("ball", (math.cos(a) * 0.12, HEAD_Y + 0.1 + math.sin(i * 1.3) * 0.04, -0.02 + math.sin(a) * 0.12), 0.07))
        blobs(els, hm, res=0.016, name="curls", tris=420)
    if h == "long":
        blobs([("ellipsoid", (0, HEAD_Y - 0.12, -0.09), 0.15, (1.05, 1.5, 0.5))], hm, res=0.016, name="long_hair", tris=220)
    if h == "beard":
        blobs([("ellipsoid", (0, HEAD_Y - 0.085, 0.07), 0.1, (1.15, 0.72, 0.72))], hm, res=0.014, name="beard", tris=260)
    if h == "cap":
        blobs([("ellipsoid", (0, HEAD_Y - 0.01, -0.05), 0.15, (1.0, 0.75, 0.9))], hm, res=0.014, name="hair", tris=220)
        cm = mat("cap", look["cap"], rough=0.6)
        prof = [(math.cos(math.pi / 2 * i / 8) * 0.172, math.sin(math.pi / 2 * i / 8) * 0.13) for i in range(9)] + [(0.0, 0.0)]
        lathe(prof, (0, HEAD_Y + 0.05, -0.005), cm, seg=20, name="cap")
        box((0.2, 0.016, 0.12), (0, HEAD_Y + 0.06, 0.2), cm, bevel=0.006, rot=(-8, 0, 0), name="brim")


GROW = 1.1                  # the whole figure is built at about 1.6 m and grown to about 1.76 m


def _grow(f):
    """scale everything built so far about the feet: meshes, and the joints' positions (so the game reads the
    real hip height)"""
    for o in bpy.context.scene.objects:
        if o.type == "MESH": o.data.transform(Matrix.Scale(f, 4))
        o.location = o.location * f


def _person(look, rider=False):
    skin_m = mat("skin", SKIN[look["skin"]], rough=0.6)
    top_m = mat("jacket", TEAL, rough=0.55) if rider else mat("shirt", look["shirt"], rough=0.65)
    legs_m = mat("legs", "#2f3437" if rider else look["legs"], rough=0.75)
    shoe_m = mat("shoes", look["shoes"], rough=0.5)
    hair_m = mat("hair", look["hair_col"], rough=0.7)
    # hips, a short chunky body, chunky arms and mitten hands, a big round head
    blobs([("ellipsoid", (0, HIP_Y + 0.03, 0), 0.175, (1.0, 0.62, 0.8))], legs_m, res=0.022, name="hips", tris=150)
    blobs([("ellipsoid", (0, 1.0, 0), 0.2, (1.0, 1.2, 0.74)), ("ellipsoid", (0, 1.17, 0), 0.19, (1.15, 0.5, 0.7))], top_m, res=0.022, name="torso", tris=520)
    arms, skin = [], []
    for s in (1, -1):
        sh, el, wr = (s * 0.245, 1.17, 0.0), (s * 0.285, 0.96, 0.03), (s * 0.3, 0.77, 0.07)
        arms.append(("capsule", ((sh[0] + el[0]) / 2, (sh[1] + el[1]) / 2, 0.015), 0.058, 0.1, (0, 0, 90 + s * 11)))
        fore = ("capsule", ((el[0] + wr[0]) / 2, (el[1] + wr[1]) / 2, 0.05), 0.052, 0.09, (-12, 0, 90 + s * 4))
        (arms if look["sleeves"] == "long" or rider else skin).append(fore)
        skin.append(("ellipsoid", (wr[0], 0.715, 0.08), 0.068, (0.8, 1.1, 0.9)))          # mitten hand
        skin.append(("ball", (wr[0] - s * 0.045, 0.74, 0.11), 0.03))                        # its thumb
    blobs(arms, top_m, res=0.016, name="arms", tris=320)
    skin += [("capsule", (0, 1.24, 0), 0.06, 0.03, (0, 0, 90)), ("ellipsoid", (0, HEAD_Y, 0), HEAD_R, (0.95, 1.05, 0.95))]
    skin.append(("ellipsoid", (0, HEAD_Y - 0.01, HEAD_R * 0.92), 0.028, (1.0, 0.85, 0.8)))   # the nose
    for s in (1, -1): skin.append(("ellipsoid", (s * HEAD_R * 0.95, HEAD_Y, 0), 0.035, (0.5, 1.0, 0.8)))   # ears
    blobs(skin, skin_m, res=0.012, name="skin", tris=900)
    _face(hair_m, rider)
    if rider:
        helmet = mat("helmet", "#2a3236", rough=0.35)
        prof = [(math.cos(math.pi / 2 * i / 10) * 0.185, math.sin(math.pi / 2 * i / 10) * 0.2) for i in range(11)] + [(0.0, 0.0)]
        lathe(prof, (0, HEAD_Y + 0.0, -0.01), helmet, seg=22, name="helmet")
        box((0.3, 0.035, 0.05), (0, HEAD_Y + 0.0, 0.16), mat("visor_rim", TEAL, rough=0.5), name="helmet_rim")
        bag = mat("bag", TEAL, rough=0.55)
        box((0.42, 0.42, 0.26), (0, 1.05, -0.27), bag, bevel=0.04, name="bag")
        text("RAPIDO", (0, 1.07, -0.403), mat("bag_text", "#ffffff", rough=0.5), size=0.07, depth=0.004, rot=(0, 180, 0), name="bag_text")
        for s in (1, -1):
            tube([(s * 0.13, 1.22, -0.14), (s * 0.15, 1.22, 0.04), (s * 0.13, 0.92, 0.12)], 0.016, black(), name="strap")
    else:
        _hair(look, hair_m)
    for s in (1, -1):
        _leg(s, legs_m, shoe_m)
    _grow(GROW)


for _i, _look in enumerate(LOOKS):
    model("customer.%d" % _i, look=_look)(_person)
model("rider", look=dict(LOOKS[0], shoes="#2a2a2a"), rider=True)(_person)


def _hand(side):
    """a chunky cartoon forearm and hand, palm down, pointing -Z, fingertips at the origin (side 1 = right hand)"""
    skin = mat("skin", "#efbd96", rough=0.55)
    s = side
    els = [("ellipsoid", (0.002 * s, 0.0, 0.1), 0.056, (1.0, 0.48, 1.0))]                    # the palm
    fingers = [(-0.033, 0.06, 0.012, 0.0145), (-0.011, 0.062, 0.0, 0.015), (0.011, 0.061, 0.008, 0.0145), (0.032, 0.066, 0.026, 0.013)]
    for (fx, z0, z1, r) in fingers:
        a = Vector((fx * s, 0.0, z0)); b = Vector((fx * 1.1 * s, -0.01, z1 + r))
        mid = (a + b) / 2
        d = b - a
        yaw = math.degrees(math.atan2(d.x, d.z))
        els.append(("capsule", tuple(mid), r, d.length / 2, (0, yaw + 90, 0)))
    els.append(("capsule", (-0.058 * s, -0.01, 0.085), 0.017, 0.026, (0, 90 - s * 32, 0)))   # the thumb
    els.append(("capsule", (0.006 * s, 0.008, 0.27), 0.04, 0.12, (0, 90, 0)))                 # the forearm
    blobs(els, skin, res=0.005, name="hand", tris=1400)
    whites = mat("chef_whites", "#f8f7f2", rough=0.8)
    cyl(0.056, 0.15, (0.008 * s, 0.008, 0.43), whites, axis="z", seg=16, name="sleeve")
    torus(0.055, 0.013, (0.008 * s, 0.008, 0.355), whites, seg=16, rseg=8, rot=(90, 0, 0), name="cuff")


model("hand.right", side=1)(_hand)
model("hand.left", side=-1)(_hand)
