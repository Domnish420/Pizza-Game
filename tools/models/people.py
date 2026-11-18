"""People: six customers, the delivery-app rider, and your own forearms and hands.

The style is a soft clay toy (see the reference in DESIGN.md, "The people"): a big wide head, about a third of
the figure, with a round bulb of a nose, ears that stick out, small glossy bead eyes (or happy closed ones), thick
brows, rosy cheeks and a wide open smile with teeth; sculpted hair in chunky clumps and curls; a soft body that
differs per person (a kid, a plump granny, a big-bellied papa, a tall thin businessman); clothes with their details
(a hoodie with its hood, pocket and drawstrings, a floral cardigan with a round collar and buttons, a varsity jacket,
a suit and tie, a quilted puffer); four-finger cartoon hands on the arms; big shoes with real soles.
Every face part, pocket, zip and strap is laid on the body's actual surface (rays cast onto the mesh), so nothing
floats or sinks. Each leg hangs from a named joint (hip_l / hip_r, with knee_l / knee_r below), each arm from
shoulder_* with the forearm and hand on elbow_*, and the head from neck, so the game can walk them, sit them at a
table and have them gesture. They face +Z. Adults' faces are at about your eye height (1.6 m), so they look you in the
eye over the van's ledge. The first-person hands point forward (-Z) with the fingertips at the origin."""
import math
from lib import *
from common import *
from mathutils.bvhtree import BVHTree
from lib import _finish_bm

SKIN = {"fair": "#f4cba8", "rosy": "#f2c2a0", "warm": "#e3a77c", "tan": "#c98b5c", "brown": "#8d5a3b", "deep": "#5e3a26"}

# ---------------------------------------------------------------- the frame: where everything on one body goes

class _F:
    pass


def _frame(hip=0.6, w=1.0, d=1.0, belly=0.0, hk=1.0):
    """hip: the hip joints' height (longer or shorter legs); w, d: how wide and deep the body is; belly: 0 flat,
    1 a big round belly; hk: the head's size against the body (a kid's head is big for its body)"""
    f = _F()
    f.hip, f.knee, f.w, f.d, f.belly = hip, hip * 0.55, w, d, belly
    f.pelvis_y = hip + 0.05
    f.torso_y = hip + 0.31
    f.shoulder_y = hip + 0.54
    f.neck = hip + 0.65
    f.r = 0.29 * hk
    f.head_y = f.neck + 0.31 * hk
    out = 0.07 * belly
    f.sh = (0.25 * w, hip + 0.53, 0.0)
    f.el = (0.33 * w + out, hip + 0.33, 0.03)
    f.wr = (0.345 * w + out, hip + 0.15, 0.07)
    f.leg_x = 0.105 * w
    return f


def _surface(ob):
    me = ob.data
    mw = ob.matrix_world
    return BVHTree.FromPolygons([mw @ v.co for v in me.vertices], [p.vertices[:] for p in me.polygons])


def _on(bvh, x, y, out=0.0, back=False):
    """the point on the front (or back) of a surface straight in from (x, y), moved out along the surface by `out`
    (in, if negative), and the surface's normal there"""
    z0, dz = (-2.0, 1.0) if back else (2.0, -1.0)
    hit, nrm, _, _ = bvh.ray_cast(Vector((x, y, z0)), Vector((0, 0, dz)))
    if hit is None: return Vector((x, y, 0.0)), Vector((0, 0, -dz))
    return hit + nrm * out, nrm


def _toward(bvh, p, axis, out=0.0):
    """the point on a surface found by looking from outside, through p, toward the point `axis` inside the body"""
    a = Vector(axis)
    d = (Vector(p) - a)
    if d.length < 1e-6: d = Vector((0, 0, 1))
    d.normalize()
    hit, nrm, _, _ = bvh.ray_cast(a + d * 1.5, -d)
    if hit is None: return Vector(p), d
    return hit + nrm * out, nrm


def _facing(n, base_x=0.0):
    """rot (degrees) that turns a part's +Z (or, with base_x 90, a torus's axis) to point along n"""
    return (base_x - math.degrees(math.asin(max(-1.0, min(1.0, n.y)))), math.degrees(math.atan2(n.x, n.z)), 0.0)


def _decal(bvh, outline, m, out=0.0025, name="decal", rings=3, back=False):
    """a flat shape laid on a surface (a mouth, a pocket, a lapel): outline is a closed loop of (x, y) points as seen
    from the front (or the back), star-shaped round its middle; every vertex sits on the surface, so it bends with it"""
    cx = sum(p[0] for p in outline) / len(outline)
    cy = sum(p[1] for p in outline) / len(outline)
    dense = []                                # cut long edges, so the outline follows the surface between its corners
    for i in range(len(outline)):
        a, b = outline[i], outline[(i + 1) % len(outline)]
        n = max(1, int(math.hypot(b[0] - a[0], b[1] - a[1]) / 0.018))
        dense += [(a[0] + (b[0] - a[0]) * t / n, a[1] + (b[1] - a[1]) * t / n) for t in range(n)]
    outline = dense
    rings = max(rings, int(max(math.hypot(x - cx, y - cy) for (x, y) in outline) / 0.024) + 1)
    bm = bmesh.new()
    c = bm.verts.new(_on(bvh, cx, cy, out, back)[0])
    loops = [[bm.verts.new(_on(bvh, cx + (x - cx) * r / rings, cy + (y - cy) * r / rings, out, back)[0]) for (x, y) in outline]
             for r in range(1, rings + 1)]
    n = len(outline)
    for i in range(n): bm.faces.new([c, loops[0][i], loops[0][(i + 1) % n]])
    for r in range(rings - 1):
        A, B = loops[r], loops[r + 1]
        for i in range(n): bm.faces.new([A[i], B[i], B[(i + 1) % n], A[(i + 1) % n]])
    want = -1.0 if back else 1.0
    for f in bm.faces:
        f.normal_update()
        if f.normal.z * want < 0: f.normal_flip()
    return _finish_bm(bm, name, m, (0, 0, 0), (0, 0, 0), True, None)


def _ellipse(cx, cy, rx, ry, n=20, a0=0.0):
    return [(cx + math.cos(a0 + 2 * math.pi * i / n) * rx, cy + math.sin(a0 + 2 * math.pi * i / n) * ry) for i in range(n)]


def _spline(pts, per=6):
    """a smooth curve through the points (Catmull-Rom)"""
    P = [Vector(p) for p in pts]
    out = []
    for i in range(len(P) - 1):
        p0, p1, p2, p3 = P[max(i - 1, 0)], P[i], P[i + 1], P[min(i + 2, len(P) - 1)]
        for k in range(per):
            t = k / per
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(P[-1])
    return out


def _band(bvh, path, axis_of, width, thick, m, name="strap", per=6):
    """a flat strap laid over a body: through the path's points (smoothed), each pressed onto the surface by looking
    toward axis_of(point) from outside; a band `width` wide and `thick` thick, lying flat on the surface"""
    pts = _spline(path, per)
    cen, nrm = [], []
    for p in pts:
        hit, n = _toward(bvh, p, axis_of(p))
        cen.append(hit + n * (thick / 2 + 0.003))
        nrm.append(n)
    for _ in range(2):                        # smooth the normals along the strap so it does not twist
        nrm = [((nrm[max(i - 1, 0)] + nrm[i] * 2 + nrm[min(i + 1, len(nrm) - 1)]) / 4).normalized() for i in range(len(nrm))]
    bm = bmesh.new()
    rings = []
    for i, c in enumerate(cen):
        t = (cen[min(i + 1, len(cen) - 1)] - cen[max(i - 1, 0)]).normalized()
        n = (nrm[i] - t * nrm[i].dot(t)).normalized()
        b = t.cross(n).normalized()
        rings.append([bm.verts.new(c + b * sx * width / 2 + n * sy * thick / 2) for (sx, sy) in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
    for j in range(len(rings) - 1):
        for k in range(4):
            bm.faces.new([rings[j][k], rings[j][(k + 1) % 4], rings[j + 1][(k + 1) % 4], rings[j + 1][k]])
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _finish_bm(bm, name, m, (0, 0, 0), (0, 0, 0), False, None)


def _ring(bvh, y, cx, cz, out, r, m, name="seam", n=28, x_scale=1.0):
    """a ridge running round a body at height y (a puffer jacket's quilting, a waistband): found by looking in toward
    the body's middle from all round"""
    pts = []
    for i in range(n + 1):
        a = 2 * math.pi * i / n
        hit, nr = _toward(bvh, (cx + math.sin(a) * 0.5 * x_scale, y, cz + math.cos(a) * 0.5), (cx, y, cz), out)
        pts.append(hit)
    return tube(pts, r, m, seg=6, name=name)


def _mix(a, b, t):
    ca, cb = [int(a[i:i + 2], 16) for i in (1, 3, 5)], [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return "#%02x%02x%02x" % tuple(int(ca[i] + (cb[i] - ca[i]) * t) for i in range(3))


# ---------------------------------------------------------------- legs and shoes

def _leg(f, side, c):
    """one short leg hanging from its hip joint, bending at the knee, in trousers, shorts or bare under a skirt,
    with a big shoe"""
    tag = "l" if side > 0 else "r"
    x = side * f.leg_x
    hip = empty("hip_" + tag, (x, f.hip, 0))
    knee = empty("knee_" + tag, (0, f.knee - f.hip, 0), parent=hip)
    low = c["legs"]
    skin_m = mat("skin", SKIN[c["skin"]], rough=0.62)
    leg_m = mat("trousers", c["legs_col"], rough=0.8, tex=c.get("legs_tex"), uvs=c.get("legs_uvs", 0.2))
    top_m = skin_m if low == "skirt" else leg_m
    shin_m = skin_m if low in ("skirt", "shorts") else leg_m
    lr = 0.092 * f.w ** 0.5
    thigh = blobs([("capsule", (x, (f.hip + f.knee) / 2, 0), lr, (f.hip - f.knee) / 2, (0, 0, 90))], top_m, res=0.02, name="thigh_" + tag, tris=170)
    parts_hi = [thigh]
    sock_y = 0.1
    shin = blobs([("capsule", (x, (f.knee + sock_y) / 2, 0), lr * 0.86, (f.knee - sock_y) / 2, (0, 0, 90))], shin_m, res=0.02, name="shin_" + tag, tris=150)
    parts_lo = [shin]
    if low == "shorts":
        # the shorts' legs end above the knee; white socks above the shoes
        parts_hi.append(torus(lr * 1.02, 0.014, (x, f.knee + 0.06, 0), leg_m, seg=16, rseg=5, name="shorts_hem"))
        parts_lo.append(cyl(lr * 0.9, 0.09, (x, 0.13, 0.01), mat("sock", "#f4f2ec", rough=0.8), seg=14, name="sock"))
        parts_lo.append(torus(lr * 0.9, 0.012, (x, 0.175, 0.01), mat("sock", "#f4f2ec", rough=0.8), seg=14, rseg=5, name="sock_top"))
    elif c.get("rolled"):
        parts_lo.append(torus(lr * 0.9, 0.024, (x, 0.15, 0.0), mat("turnup", c.get("rolled_col", "#9db3cc"), rough=0.8), seg=16, rseg=6, name="turn_up"))
    # the shoe: its upper, a thick sole, a toe cap and laces on a sneaker, a heel on a leather shoe
    kind, col = c["shoes"], c["shoe_col"]
    up_m = mat("shoe_" + col, col, rough=0.45 if kind == "leather" else 0.6)
    els = [("ellipsoid", (x * 1.04, 0.075, 0.05), 0.088, (0.95, 0.72, 1.5))]
    shoe = blobs(els, up_m, res=0.014, name="shoe_" + tag, tris=200)
    sole_col = "#f6f4ee" if kind == "sneaker" else "#2b211b"
    sole = blobs([("ellipsoid", (x * 1.04, 0.03, 0.055), 0.098, (0.98, 0.32, 1.48))], mat("sole_" + sole_col, sole_col, rough=0.7), res=0.012, name="sole_" + tag, tris=160)
    extra = [shoe, sole]
    if kind == "sneaker":
        extra.append(sphere(0.064, (x * 1.04, 0.058, 0.145), mat("sole_" + sole_col, sole_col, rough=0.7), seg=14, rings=8, scale=(1.15, 0.62, 0.8), name="toe_cap"))
        for k in range(3):
            zz = 0.02 + k * 0.03
            yt = 0.075 + 0.0634 * math.sqrt(max(0.0, 1 - ((zz - 0.05) / 0.132) ** 2))
            tube([(x * 1.04 - 0.03, yt - 0.006, zz), (x * 1.04, yt + 0.002, zz + 0.004), (x * 1.04 + 0.03, yt - 0.006, zz)], 0.0065, mat("lace", "#ffffff", rough=0.6), seg=6, name="lace")
    elif kind == "leather":
        extra.append(box((0.1, 0.03, 0.06), (x * 1.04, 0.022, -0.06), mat("sole_" + sole_col, sole_col, rough=0.7), bevel=0.008, name="heel"))
    bottom = min((o.matrix_world @ v.co).y for o in extra for v in o.data.vertices)
    for o in extra: o.data.transform(Matrix.Translation(Vector((0, -bottom, 0))))     # soles exactly on the ground
    parts_lo += extra
    for o in parts_hi:
        o.data.transform(Matrix.Translation(Vector((-x, -f.hip, 0))))
        o.parent = hip
    for o in parts_lo:
        o.data.transform(Matrix.Translation(Vector((-x, -f.knee, 0))))
        o.parent = knee


# ---------------------------------------------------------------- arms and hands

def _arm(f, s, c, top_m, skin_m):
    """a short arm: the upper arm on the shoulder; the forearm, a cuff and a four-finger cartoon hand on the elbow"""
    tag = "l" if s > 0 else "r"
    sh = (s * f.sh[0], f.sh[1], f.sh[2])
    el = (s * f.el[0], f.el[1], f.el[2])
    wr = (s * f.wr[0], f.wr[1], f.wr[2])
    shoulder = empty("shoulder_" + tag, sh)
    elbow = empty("elbow_" + tag, (el[0] - sh[0], el[1] - sh[1], el[2] - sh[2]), parent=shoulder)
    ar = 0.08
    tilt = math.degrees(math.atan2(el[0] - sh[0], sh[1] - el[1]))
    upper = blobs([("ball", sh, ar * 1.05), ("capsule", ((sh[0] + el[0]) / 2, (sh[1] + el[1]) / 2, 0.015), ar, 0.085, (0, 0, 90 + tilt * s * s))], top_m, res=0.016, name="upper_arm_" + tag, tris=220)
    ups = [upper]
    sleeve = c.get("sleeves", "long")
    sleeve_m = mat("sleeve", c["sleeve_col"], rough=0.7, tex=c.get("sleeve_tex"), uvs=c.get("top_uvs", 0.25)) if c.get("sleeve_col") else top_m
    if sleeve_m is not top_m:
        ups = [blobs([("ball", sh, ar * 1.05), ("capsule", ((sh[0] + el[0]) / 2, (sh[1] + el[1]) / 2, 0.015), ar, 0.085, (0, 0, 90 + tilt))], sleeve_m, res=0.016, name="upper_arm_" + tag, tris=220)]
        bpy.data.objects.remove(upper)
    ftilt = math.degrees(math.atan2(wr[0] - el[0], el[1] - wr[1]))
    fore_m = skin_m if sleeve == "short" else sleeve_m
    fore = blobs([("ball", el, ar * 0.9), ("capsule", ((el[0] + wr[0]) / 2, (el[1] + wr[1]) / 2, (el[2] + wr[2]) / 2), ar * 0.88, 0.075, (-12, 0, 90 + ftilt))], fore_m, res=0.016, name="forearm_" + tag, tris=200)
    lows = [fore]
    if sleeve == "short":
        ups.append(torus(ar * 1.02, 0.016, ((sh[0] + el[0] * 2) / 3, (sh[1] + el[1] * 2) / 3 + 0.02, 0.02), sleeve_m, seg=16, rseg=6, rot=(0, 0, tilt), name="sleeve_hem"))
    else:
        cuff_m = mat("cuff", c.get("cuff_col", c["sleeve_col"] if c.get("sleeve_col") else c["top_col"]), rough=0.75)
        lows.append(torus(ar * 0.86, 0.02, (wr[0], wr[1] + 0.025, wr[2]), cuff_m, seg=16, rseg=6, rot=(0, 0, ftilt), name="cuff"))
        for k, sc in enumerate(c.get("cuff_stripes", [])):
            lows.append(torus(ar * 0.9, 0.006, (wr[0], wr[1] + 0.035 - k * 0.016, wr[2]), mat("stripe_" + sc, sc, rough=0.7), seg=16, rseg=4, rot=(0, 0, ftilt), name="cuff_stripe"))
    # a big cartoon hand: the palm turned in to the leg, three chunky fingers (each its own shape, so they read as
    # fingers) hanging and curling a little forward and in, the thumb in front
    px, py, pz = wr[0], wr[1] - 0.07, wr[2] + 0.014
    lows.append(blobs([("ellipsoid", (px, py, pz), 0.074, (0.62, 1.0, 1.05)), ("ball", (px, wr[1] - 0.012, wr[2]), 0.056)], skin_m, res=0.009, name="palm_" + tag, tris=320))
    for k, dz in enumerate((-0.044, 0.0, 0.044)):
        ln = (0.92, 1.0, 0.9)[k]
        top = Vector((px - s * 0.002, py - 0.04, pz + dz))
        mid = top + Vector((-s * 0.007, -0.048 * ln, 0.01))
        tip = mid + Vector((-s * 0.01, -0.034 * ln, 0.018))
        lows.append(tube([tuple(top), tuple(mid), tuple(tip)], 0.026, skin_m, seg=10, radii=[0.027, 0.026, 0.024], caps=False, name="finger"))
        lows.append(sphere(0.024, tuple(tip), skin_m, seg=10, rings=6, name="fingertip"))
    tb = Vector((px - s * 0.014, py + 0.006, pz + 0.054))
    tt = tb + Vector((-s * 0.014, -0.046, 0.036))
    lows.append(tube([tuple(tb), tuple((tb + tt) / 2 + Vector((0, 0, 0.007))), tuple(tt)], 0.027, skin_m, seg=10, radii=[0.029, 0.027, 0.025], caps=False, name="thumb"))
    lows.append(sphere(0.025, tuple(tt), skin_m, seg=10, rings=6, name="thumb_tip"))
    if c.get("rolling_pin") == tag:
        wood = mat("pin_wood", "#c9935a", rough=0.6)
        c0 = Vector((px - s * 0.03, py - 0.035, pz + 0.03))
        lows.append(cyl(0.032, 0.36, tuple(c0), wood, axis="z", seg=16, bevel=0.01, rot=(-25, 0, 0), name="rolling_pin"))
        for e in (-1, 1):
            d = Vector((0, math.sin(math.radians(-25)) * -0.22 * e, math.cos(math.radians(25)) * 0.22 * e))
            lows.append(cyl(0.017, 0.09, tuple(c0 + d), wood, axis="z", seg=12, bevel=0.006, rot=(-25, 0, 0), name="pin_handle"))
    if c.get("phone") == tag:
        ph = box((0.014, 0.12, 0.066), (px - s * 0.035, py - 0.03, pz + 0.035), mat("phone", "#22272b", rough=0.4), bevel=0.006, rot=(-20, 0, 0), name="phone")
        scr = box((0.002, 0.1, 0.054), (px - s * 0.043, py - 0.03, pz + 0.035), mat("screen", "#7fb6e8", rough=0.3, emit="#9cc9f2", emit_k=0.8), bevel=0.0, rot=(-20, 0, 0), name="screen")
        lows += [ph, scr]
    for o in ups:
        o.data.transform(Matrix.Translation(-Vector(sh)))
        o.parent = shoulder
    for o in lows:
        o.data.transform(Matrix.Translation(-Vector(el)))
        o.parent = elbow


# ---------------------------------------------------------------- the head and face

def _head(f, c):
    """a big wide head: cheeks and jaw, a round nose, ears that stick out (all one soft shape)"""
    R, Y = f.r, f.head_y
    skin_m = mat("skin", SKIN[c["skin"]], rough=0.62)
    els = [("capsule", (0, f.neck + 0.01, 0), 0.085, 0.035, (0, 0, 90)),
           ("ellipsoid", (0, Y, 0), R, (1.06, 0.96, 0.95)),
           ("ellipsoid", (0, Y - 0.38 * R, 0.1 * R), 0.8 * R, (1.1, 0.72, 0.92)),
           ("ellipsoid", (0, Y - 0.17 * R, 0.86 * R), 0.2 * R, (1.18, 0.92, 0.95))]
    ear_c = lambda s: Vector((s * 1.08 * R, Y - 0.08 * R, -0.06 * R))
    ear_n = lambda s: Vector((s * math.sin(math.radians(38)), 0.0, math.cos(math.radians(38))))
    for s in (1, -1):         # ears stand out from the sides, turned a little forward
        els.append(("ellipsoid", tuple(ear_c(s)), 0.25 * R, (0.78, 1.0, 0.38), (0, s * 38, 0)))
    head = blobs(els, skin_m, res=0.0105, name="head", tris=1700)
    inner = mat("inner_ear", _mix(SKIN[c["skin"]], "#b5524a", 0.3), rough=0.7)
    for s in (1, -1):
        sphere(0.13 * R, tuple(ear_c(s) + ear_n(s) * 0.075 * R), inner, seg=12, rings=8, scale=(1.0, 1.3, 0.25), rot=(0, s * 38, 0), name="inner_ear")
        if c.get("earrings"):
            sphere(0.04 * R, (s * 1.08 * R, Y - 0.33 * R, -0.03 * R), mat("gold", CHEESE, rough=0.35, metal=0.3), seg=8, rings=6, name="earring")
        if c.get("hoops"):
            torus(0.11 * R, 0.022 * R, (s * 1.1 * R, Y - 0.42 * R, -0.03 * R), mat("gold", CHEESE, rough=0.35, metal=0.3), seg=18, rseg=5, rot=(0, s * 38, 90), name="hoop")
    return head


def _face(f, c, head, hair_m):
    R, Y = f.r, f.head_y
    bvh = _surface(head)
    eye_m = mat("eye", "#1b1512", rough=0.12)
    shine_m = mat("shine", "#ffffff", rough=0.2, emit="#ffffff", emit_k=0.8)
    blush_m = mat("blush", _mix(SKIN[c["skin"]], "#ff6a66", 0.42), rough=0.65)
    ey = Y + 0.04 * R
    for s in (1, -1):
        ex = s * 0.34 * R
        if c.get("eyes") == "happy":
            pts = [_on(bvh, ex + t * 0.12 * R, ey - 0.02 * R + 0.07 * R * (1 - t * t), 0.004)[0] for t in (-1, -0.5, 0, 0.5, 1)]
            tube(pts, 0.024 * R, eye_m, seg=8, radii=[0.018 * R, 0.024 * R, 0.026 * R, 0.024 * R, 0.018 * R], name="eye_shut")
        else:
            p, n = _on(bvh, ex, ey, -0.004)
            sphere(0.115 * R, p, eye_m, seg=16, rings=10, scale=(0.8, 1.12, 0.45), rot=_facing(n), name="eye")
            sphere(0.032 * R, p + n * 0.045 * R + Vector((0.038 * R, 0.05 * R, 0)), shine_m, seg=8, rings=6, name="shine")
            sphere(0.016 * R, p + n * 0.046 * R + Vector((-0.03 * R, -0.045 * R, 0)), shine_m, seg=6, rings=4, name="shine")
        brow = [_on(bvh, s * x * R, Y + y * R, 0.005)[0] for (x, y) in ((0.2, 0.27), (0.34, 0.33), (0.48, 0.28))]
        tube(brow, 0.04 * R, hair_m if not c.get("brow_col") else mat("brow", c["brow_col"], rough=0.7), seg=8, radii=[0.028 * R, 0.042 * R, 0.026 * R], name="brow")
        b, bn = _on(bvh, s * 0.56 * R, Y - 0.28 * R, -0.006)
        sphere(0.15 * R, b, blush_m, seg=14, rings=8, scale=(1.15, 0.72, 0.22), rot=_facing(bn), name="blush")
    if c.get("freckles"):
        fm = mat("freckle", _mix(SKIN[c["skin"]], "#8a3f1a", 0.55), rough=0.7)
        for s in (1, -1):
            for (fx, fy) in ((0.3, -0.16), (0.4, -0.2), (0.34, -0.25), (0.47, -0.13), (0.24, -0.22)):
                p, n = _on(bvh, s * fx * R, Y + fy * R, -0.001)
                sphere(0.02 * R, p, fm, seg=6, rings=4, scale=(1, 1, 0.4), rot=_facing(n), name="freckle")
    # the mouth: wide open, with its top teeth and tongue (under a moustache for the papa)
    mw = 0.27 * R * c.get("mouth_w", 1.0)
    top_y, depth = Y - 0.42 * R, 0.29 * R * c.get("mouth_d", 1.0)
    top = [(mw * t, top_y - 0.05 * R * (1 - t * t)) for t in [-1 + 2 * i / 8 for i in range(9)]]
    bot = [(mw * math.cos(a), top_y - depth * math.sin(a)) for a in [math.pi * i / 10 for i in range(1, 10)]]
    _decal(bvh, list(reversed(top)) + bot, mat("mouth", "#4c1716", rough=0.5), out=0.002, name="mouth")
    teeth = [(mw * 0.82 * t, top_y - 0.05 * R * (1 - t * t) - 0.005 * R) for t in [-1 + 2 * i / 8 for i in range(9)]]
    teeth_b = [(x, y - 0.085 * R) for (x, y) in reversed(teeth)]
    _decal(bvh, teeth + teeth_b, mat("teeth", "#fbf7ee", rough=0.4), out=0.0035, name="teeth", rings=2)
    _decal(bvh, _ellipse(0, top_y - depth * 0.72, mw * 0.5, depth * 0.28), mat("tongue", "#de6266", rough=0.5), out=0.0035, name="tongue", rings=2)
    if c.get("moustache"):
        mm = mat("moustache", c["hair_col"], rough=0.7)
        els = []
        for s in (1, -1):
            for (x, y, r, sc, rz) in ((0.13, -0.33, 0.15, (1.5, 0.72, 0.85), -12), (0.33, -0.33, 0.12, (1.3, 0.62, 0.8), 18), (0.47, -0.22, 0.075, (0.9, 1.2, 0.8), 40)):
                p, n = _on(bvh, s * x * R, Y + y * R, 0.03 * R)
                els.append(("ellipsoid", tuple(p), r * R, sc, (0, 0, s * rz)))
        blobs(els, mm, res=0.008, name="moustache", tris=500)
    if c.get("glasses"):
        frame = mat("glasses", "#1f1f22", rough=0.35)
        rims = []
        for s in (1, -1):
            p, n = _on(bvh, s * 0.34 * R, ey, 0.07 * R)
            torus(0.25 * R, 0.035 * R, p, frame, seg=24, rseg=6, rot=_facing(n, 90), name="lens_rim")
            sphere(0.24 * R, p - n * 0.01 * R, mat("lens", "#dfeef5", rough=0.05, alpha=0.18), seg=16, rings=10, scale=(1, 1, 0.12), rot=_facing(n), name="lens")
            rims.append(p)
            tube([p + Vector((s * 0.24 * R, 0.02 * R, -0.02 * R)), Vector((s * 1.02 * R, ey + 0.02 * R, -0.2 * R))], 0.025 * R, frame, name="glasses_arm")
        tube([rims[1] + Vector((0.24 * R, 0, 0)), _on(bvh, 0.0, ey + 0.04 * R, 0.07 * R)[0], rims[0] - Vector((0.24 * R, 0, 0))], 0.03 * R, frame, name="bridge")


# ---------------------------------------------------------------- hair and hats

def _hair_cap(f, hm, front=0.5, back=-0.42, grow=1.07, name="hair"):
    """the head's hair as a cap with a crisp hairline `front` (x the head's radius) above the head's middle at the
    forehead and `back` at the nape, level from side to side, so it sweeps down over the temples"""
    R, Y = f.r, f.head_y
    rx, ry, rz = R * 1.06 * grow, R * 0.96 * (grow + 0.01), R * 0.95 * grow
    zf = R * 0.95
    slope = (front - back) * R / (2 * zf)
    return cap((0, Y + 0.03 * R, -0.02 * R), (rx, ry, rz), (0, Y + front * R, zf), (0, 1, -slope), hm, name=name)


def _shell_pts(f, n, keep, lift=0.0, radius=1.0, seed=7):
    """points spread evenly over the head's crown (a golden spiral), kept where keep(point) says"""
    R, Y = f.r, f.head_y
    c = Vector((0, Y + lift * R, -0.04 * R))
    out = []
    for i in range(n):
        y = 1 - 2 * (i + 0.5) / n
        rr = math.sqrt(1 - y * y)
        a = i * 2.39996
        p = c + Vector((math.cos(a) * rr * 1.06, y * 0.96, math.sin(a) * rr * 0.95)) * R * radius
        if keep(p): out.append(p)
    return out


def _hair(f, c, head):
    R, Y = f.r, f.head_y
    hm = mat("hair", c["hair_col"], rough=0.72)
    h = c["hair"]
    if h == "kid_cap":                         # short brown hair under a cap worn backwards, tufts poking out
        _hair_cap(f, hm, 0.46, -0.45, grow=1.06)
        tufts = []
        for k in range(5):
            a = (k - 2) * 0.32
            tufts.append(("ellipsoid", (math.sin(a) * 0.62 * R, Y + 0.5 * R, math.cos(a) * 0.8 * R), 0.16 * R, (1.0, 0.7, 1.1), (-40, math.degrees(a), 0)))
        for s in (1, -1):
            tufts.append(("ellipsoid", (s * 0.98 * R, Y + 0.22 * R, 0.15 * R), 0.14 * R, (0.7, 1.0, 1.2)))
        blobs(tufts, hm, res=0.008, name="tufts", tris=420)
        cm = mat("cap", c["hat_col"], rough=0.6)
        cap((0, Y + 0.08 * R, -0.02 * R), (R * 1.13, R * 1.02, R * 1.1), (0, Y + 0.42 * R, 0), (0, 1, -0.2), cm, name="cap")
        blobs([("ellipsoid", (0, Y + 0.27 * R, -1.2 * R), 0.46 * R, (1.0, 0.13, 1.0), (-14, 0, 0))], cm, res=0.008, name="brim", tris=260)
        sphere(0.07 * R, (0, Y + 1.08 * R, -0.02 * R), cm, seg=10, rings=6, name="button")
        box((0.4 * R, 0.07 * R, 0.05 * R), (0, Y + 0.64 * R, 1.0 * R), mat("strap", "#2b2b2b", rough=0.6), bevel=0.01 * R, rot=(-35, 0, 0), name="cap_strap")
    elif h == "granny":                        # soft grey waves round the face and a bun on top
        _hair_cap(f, hm, 0.5, -0.5, grow=1.08)
        els = []
        for k in range(9):
            a = (k - 4) * 0.36
            els.append(("ellipsoid", (math.sin(a) * 0.9 * R, Y + (0.48 - 0.22 * abs(math.sin(a))) * R, math.cos(a) * 0.86 * R), 0.2 * R, (1.0, 0.75, 0.9), (0, math.degrees(a), 0)))
        for s in (1, -1):
            els.append(("ellipsoid", (s * 1.0 * R, Y + 0.0 * R, -0.12 * R), 0.22 * R, (0.7, 1.15, 1.0)))
        els.append(("ellipsoid", (0, Y + 1.0 * R, -0.22 * R), 0.36 * R, (1.0, 0.85, 0.95)))
        blobs(els, hm, res=0.009, name="waves", tris=800)
        torus(0.27 * R, 0.05 * R, (0, Y + 0.86 * R, -0.2 * R), mat("bun_band", _mix(c["hair_col"], "#8a8f96", 0.5), rough=0.6), seg=18, rseg=6, rot=(-14, 0, 0), name="bun_wrap")
    elif h == "curls":                         # a mop of tight ginger curls
        _hair_cap(f, hm, 0.42, -0.42, grow=1.06)
        pts = _shell_pts(f, 110, lambda p: (p.y > Y + 0.4 * R or p.z < -0.05 * R) and p.y > Y - 0.5 * R, lift=0.05, radius=1.1)
        hm2 = mat("hair_light", _mix(c["hair_col"], "#ffd08a", 0.22), rough=0.7)
        for i, p in enumerate(pts):       # each curl its own ball, a little flattened onto the head, two shades
            n = (p - Vector((0, Y, -0.04 * R))).normalized()
            sphere(R * (0.15 + 0.035 * ((i * 7) % 3)), tuple(p), hm if i % 3 else hm2, seg=8, rings=5, scale=(1.0, 1.0, 0.8), rot=_facing(n), name="curl")
    elif h == "beanie":                        # purple hair to the jaw under a grey beanie
        els = []
        for s in (1, -1):
            els.append(("ellipsoid", (s * 1.0 * R, Y + 0.02 * R, -0.08 * R), 0.36 * R, (0.6, 1.55, 1.35)))      # from under the beanie to the jaw
            els.append(("ellipsoid", (s * 0.93 * R, Y - 0.3 * R, 0.28 * R), 0.17 * R, (0.75, 1.7, 0.85), (0, 0, s * -8)))   # a lock by the cheek
            els.append(("ellipsoid", (s * 0.55 * R, Y + 0.42 * R, 0.7 * R), 0.2 * R, (1.2, 0.75, 0.7), (0, 0, s * 30)))   # fringe
        els.append(("ellipsoid", (0, Y - 0.15 * R, -0.62 * R), 0.6 * R, (1.6, 1.25, 0.65)))
        blobs(els, hm, res=0.01, name="hair", tris=800)
        bm_ = mat("beanie", c["hat_col"], rough=0.85)
        cap((0, Y + 0.2 * R, -0.04 * R), (R * 1.12, R * 1.16, R * 1.1), (0, Y + 0.5 * R, R), (0, 1, -0.32), bm_, name="beanie")
        lathe([(1.0, -0.5), (1.045, -0.3), (1.045, 0.3), (1.0, 0.5)], (0, Y + 0.56 * R, -0.04 * R), mat("beanie_cuff", _mix(c["hat_col"], "#000000", 0.12), rough=0.9), seg=32,
              scale=(R * 1.1, 0.26 * R, R * 1.08), rot=(-17, 0, 0), name="beanie_cuff")
    elif h == "swept":                         # a side-parted quiff swept up and over
        _hair_cap(f, hm, 0.55, -0.42, grow=1.06)
        blobs([("ellipsoid", (0.12 * R, Y + 0.84 * R, 0.5 * R), 0.42 * R, (1.35, 0.6, 0.9), (-22, 0, -10)),
               ("ellipsoid", (-0.42 * R, Y + 0.78 * R, 0.32 * R), 0.32 * R, (1.2, 0.62, 1.1), (-10, 0, 14)),
               ("ellipsoid", (0.5 * R, Y + 0.7 * R, 0.25 * R), 0.3 * R, (1.0, 0.7, 1.1)),
               ("ellipsoid", (0.98 * R, Y + 0.15 * R, 0.1 * R), 0.12 * R, (0.6, 1.4, 0.9)),
               ("ellipsoid", (-0.98 * R, Y + 0.15 * R, 0.1 * R), 0.12 * R, (0.6, 1.4, 0.9))], hm, res=0.009, name="quiff", tris=700)
    elif h == "papa":                          # short dark hair, full at the top, sideburns
        _hair_cap(f, hm, 0.55, -0.4, grow=1.09)
        blobs([("ellipsoid", (0.1 * R, Y + 0.74 * R, 0.62 * R), 0.26 * R, (1.5, 0.62, 0.9), (-20, 0, -8)),
               ("ellipsoid", (0.98 * R, Y + 0.08 * R, 0.12 * R), 0.13 * R, (0.6, 1.5, 0.9)),
               ("ellipsoid", (-0.98 * R, Y + 0.08 * R, 0.12 * R), 0.13 * R, (0.6, 1.5, 0.9))], hm, res=0.01, name="top", tris=500)
    elif h == "ponytail":                      # hair pulled back into a high ponytail with a scrunchie, a swept fringe
        _hair_cap(f, hm, 0.5, -0.4, grow=1.07)
        blobs([("ellipsoid", (0.18 * R, Y + 0.6 * R, 0.76 * R), 0.22 * R, (1.6, 0.55, 0.7), (-15, 0, -18))], hm, res=0.009, name="fringe", tris=260)
        tie = Vector((0, Y + 0.62 * R, -0.98 * R))
        els = [("ball", tuple(tie), 0.17 * R)]
        for i in range(1, 7):
            els.append(("ball", tuple(tie + Vector((0, -0.2 * R * i, -0.16 * R * i + 0.022 * R * i * i))), (0.2 - 0.016 * i) * R))
        blobs(els, hm, res=0.01, name="ponytail", tris=500)
        torus(0.13 * R, 0.055 * R, tuple(tie + Vector((0, -0.02 * R, 0.05 * R))), mat("scrunchie", c.get("tie_col", "#e86a8a"), rough=0.7), seg=16, rseg=6, rot=(70, 0, 0), name="scrunchie")
    elif h == "chef":                          # short dark hair under a tall pleated toque
        _hair_cap(f, hm, 0.45, -0.42, grow=1.06)
        white = mat("toque", "#f8f6f1", rough=0.75)
        lathe([(1.0, -0.5), (1.0, 0.5)], (0, Y + 0.72 * R, -0.04 * R), white, seg=32, scale=(R * 1.1, 0.5 * R, R * 1.08), rot=(-8, 0, 0), name="toque_band")
        els = [("ellipsoid", (0, Y + 1.25 * R, -0.08 * R), 0.62 * R, (1.25, 0.75, 1.2))]
        for k in range(8):
            a = 2 * math.pi * k / 8
            els.append(("ellipsoid", (math.sin(a) * 0.8 * R, Y + 1.22 * R, math.cos(a) * 0.78 * R - 0.08 * R), 0.36 * R, (1.0, 1.15, 1.0)))
        blobs(els, white, res=0.012, name="toque", tris=700)
    elif h == "paper_hat":                     # ginger curls and a folded paper hat
        _hair_cap(f, hm, 0.42, -0.42, grow=1.06)
        pts = _shell_pts(f, 90, lambda p: (p.y > Y + 0.4 * R or p.z < -0.05 * R) and p.y > Y - 0.5 * R and not (abs(p.x) < 0.5 * R and p.y > Y + 0.7 * R), lift=0.05, radius=1.1)
        hm2 = mat("hair_light", _mix(c["hair_col"], "#ffd08a", 0.22), rough=0.7)
        for i, p in enumerate(pts):
            n = (p - Vector((0, Y, -0.04 * R))).normalized()
            sphere(R * (0.15 + 0.035 * ((i * 7) % 3)), tuple(p), hm if i % 3 else hm2, seg=8, rings=5, scale=(1.0, 1.0, 0.8), rot=_facing(n), name="curl")
        paper = mat("paper_hat", "#f7f4ec", rough=0.8)
        side = [(-1.02 * R, 0.0), (1.02 * R, 0.0), (0.62 * R, 0.62 * R), (-0.62 * R, 0.62 * R)]
        for s in (1, -1):            # two panels leaning together into a ridge, front to back on the curls (a folded boat)
            slab(side, 0.02, (s * 0.4 * R - s * 0.01, Y + 0.84 * R, -0.04 * R), paper, rot=(s * -33, 90, 0), bevel=0.004, name="paper_hat")
        box((0.9 * R, 0.12 * R, 2.08 * R), (0, Y + 0.88 * R, -0.04 * R), paper, bevel=0.012, name="paper_band")
    elif h == "helmet":                        # the rider: messy hair poking out of a cycle helmet with a chin strap
        els = []
        for a_deg in (62, 82, 102, 125, 150, 180, 210, 235, 258, 278, 298):
            a = math.radians(a_deg)
            drop = 0.1 * R * ((a_deg // 20) % 2)
            els.append(("ellipsoid", (math.sin(a) * 1.08 * R, Y + 0.16 * R - drop, math.cos(a) * 1.0 * R - 0.05 * R), 0.16 * R, (0.8, 1.35, 0.8), (0, math.degrees(a), math.sin(a) * -25)))
        els.append(("ellipsoid", (0, Y - 0.25 * R, -0.85 * R), 0.4 * R, (1.5, 0.8, 0.55)))
        blobs(els, hm, res=0.009, name="messy_hair", tris=700)
        hm2 = mat("helmet", c["hat_col"], rough=0.35)
        cap((0, Y + 0.16 * R, -0.05 * R), (R * 1.2, R * 1.1, R * 1.18), (0, Y + 0.45 * R, R), (0, 1, -0.45), hm2, name="helmet")
        vent = mat("vent", "#2a2a2e", rough=0.6)
        for k in (-1, 0, 1):
            box((0.12 * R, 0.08 * R, 0.6 * R), (k * 0.32 * R, Y + 1.24 * R - abs(k) * 0.1 * R, -0.1 * R), vent, bevel=0.03 * R, rot=(0, 0, -k * 14), name="vent")
        strap = mat("chin_strap", "#232323", rough=0.6)
        hb = _surface(head)
        for s in (1, -1):
            pts = [_toward(hb, (s * x * R, Y + y * R, z * R), (0, Y - 0.3 * R, 0), 0.02 * R)[0]
                   for (x, y, z) in ((1.1, 0.2, 0.05), (1.05, -0.3, 0.2), (0.75, -0.75, 0.35), (0.35, -0.95, 0.4), (0.0, -1.0, 0.4))]
            tube(pts, 0.03 * R, strap, name="chin_strap")


# ---------------------------------------------------------------- the body and its clothes

def _body(f, c):
    """the soft body: trousers' seat or skirt, the top (longer for jackets and cardigans), a belly if they have one;
    returns the top's mesh (so its details can be laid on it) and its material"""
    W, D, B = f.w, f.d, f.belly
    top_m = mat("top", c["top_col"], rough=0.72, tex=c.get("top_tex"), uvs=c.get("top_uvs", 0.25))
    legs_m = mat("trousers", c["legs_col"], rough=0.8, tex=c.get("legs_tex"), uvs=c.get("legs_uvs", 0.2))
    if c["legs"] == "skirt":
        sk = mat("skirt", c["skirt_col"], rough=0.75)
        prof = [(0.0, 0.0), (0.2, 0.0), (0.23, -0.06), (0.27, -0.18), (0.3, -0.27), (0.29, -0.3), (0.0, -0.3)]
        lathe([(r * W, y * (f.hip - f.knee + 0.12) / 0.3) for (r, y) in prof], (0, f.hip + 0.13, 0), sk, seg=28, scale=(1.0, 1.0, 0.85 * D), name="skirt")
    else:
        blobs([("ellipsoid", (0, f.pelvis_y + 0.01, 0), 0.2, (1.0 * W, 0.55, 0.84 * D))], legs_m, res=0.02, name="hips", tris=220)
    els = [("ellipsoid", (0, f.torso_y, 0), 0.26, (W, 1.12, 0.82 * D)), ("ellipsoid", (0, f.shoulder_y, 0), 0.22, (1.12 * W, 0.55, 0.8 * D))]
    if B > 0:
        els.append(("ellipsoid", (0, f.torso_y - 0.07, 0.05 + 0.05 * B), 0.24 + 0.06 * B, (W * (1 + 0.1 * B), 1.0, 0.85 + 0.25 * B)))
    if c.get("long_top"):
        els.append(("ellipsoid", (0, f.hip + 0.1, 0), 0.22, (1.08 * W * (1 + 0.1 * B), 0.5, 0.9 * D + 0.1 * B)))
    torso = blobs(els, top_m, res=0.018, name="torso", tris=1100)
    return torso, top_m


def _clothes(f, c, torso, top_m):
    """the top's details, each laid on the body"""
    bvh = _surface(torso)
    k = c["top"]
    y0 = f.hip
    neck_m = mat("collar", c.get("collar_col", c["top_col"]), rough=0.75)
    front = lambda y: (0, y, 0)
    if k == "hoodie":
        dark = mat("hoodie_dark", _mix(c["top_col"], "#0b1a33", 0.25), rough=0.75)
        blobs([("ellipsoid", (0, f.neck - 0.02, -0.13), 0.13, (1.45, 0.62, 1.0)), ("ellipsoid", (0, f.neck - 0.07, -0.05), 0.15, (1.3, 0.4, 1.0))], top_m, res=0.012, name="hood", tris=420)
        _decal(bvh, [(-0.13, y0 + 0.24), (0.13, y0 + 0.24), (0.17, y0 + 0.08), (-0.17, y0 + 0.08)], dark, out=0.004, name="pocket", rings=3)
        _ring(bvh, y0 + 0.04, 0, 0, 0.006, 0.018, dark, name="hem") if c.get("long_top") else None
        for s in (1, -1):
            a, _ = _on(bvh, s * 0.05, f.neck - 0.07, 0.01)
            tube([a, a + Vector((s * 0.005, -0.07, 0.012)), a + Vector((s * 0.008, -0.13, 0.016))], 0.006, mat("string", "#f6f4ee", rough=0.6), name="drawstring")
            sphere(0.011, a + Vector((s * 0.008, -0.14, 0.016)), mat("string", "#f6f4ee", rough=0.6), seg=8, rings=6, scale=(1, 1.6, 1), name="aglet")
    elif k == "cardigan":
        cream = mat("collar", c["collar_col"], rough=0.7)
        for s in (1, -1):
            pts = [(s * 0.004, f.neck - 0.04), (s * 0.05, f.neck - 0.02), (s * 0.11, f.neck - 0.035), (s * 0.13, f.neck - 0.08), (s * 0.08, f.neck - 0.13), (s * 0.02, f.neck - 0.12)]
            _decal(bvh, pts, cream, out=0.006, name="round_collar", rings=3)
        _decal(bvh, [(-0.008, f.neck - 0.11), (0.008, f.neck - 0.11), (0.008, y0 + 0.02), (-0.008, y0 + 0.02)], mat("placket", _mix(c["collar_col"], "#94603e", 0.5), rough=0.7), out=0.0035, name="placket", rings=2)
        for j in range(5):
            p, n = _on(bvh, 0.0, f.neck - 0.16 - j * 0.085, 0.006)
            sphere(0.016, p, cream, seg=10, rings=6, scale=(1, 1, 0.5), rot=_facing(n), name="button")
    elif k == "tee":
        torus(0.098, 0.02, (0, f.neck - 0.012, 0.004), neck_m, seg=22, rseg=6, rot=(-6, 0, 0), name="crew_neck")
    elif k == "varsity":
        shirt = mat("shirt_under", c["under_col"], rough=0.7)
        _decal(bvh, [(-0.07, f.neck - 0.03), (0.07, f.neck - 0.03), (0.06, y0 + 0.05), (-0.06, y0 + 0.05)], shirt, out=0.003, name="shirt_front", rings=3)
        cream = mat("trim", c["sleeve_col"], rough=0.7)
        for s in (1, -1):
            for j in range(4):
                p, n = _on(bvh, s * 0.085, f.neck - 0.14 - j * 0.11, 0.006)
                sphere(0.012, p, cream, seg=8, rings=6, scale=(1, 1, 0.5), rot=_facing(n), name="snap")
        torus(0.1, 0.024, (0, f.neck - 0.012, 0.004), mat("rib", c["top_col"], rough=0.8), seg=22, rseg=6, rot=(-6, 0, 0), name="rib_collar")
        _ring(bvh, y0 + 0.08, 0, 0, 0.004, 0.022, mat("rib", c["top_col"], rough=0.8), name="rib_waist")
        _ring(bvh, y0 + 0.11, 0, 0, 0.007, 0.006, cream, name="rib_stripe")
    elif k == "suit":
        lapel = mat("lapel", _mix(c["top_col"], "#1d130c", 0.3), rough=0.6)
        white = mat("shirt_white", "#f5f2ea", rough=0.6)
        _decal(bvh, [(-0.075, f.neck - 0.02), (0.075, f.neck - 0.02), (0.0, f.neck - 0.25)], white, out=0.003, name="shirt_v", rings=3)
        _decal(bvh, [(-0.022, f.neck - 0.05), (0.022, f.neck - 0.05), (0.034, f.neck - 0.24), (0.0, f.neck - 0.29), (-0.034, f.neck - 0.24)], mat("tie", c["tie_col"], rough=0.5), out=0.006, name="tie", rings=3)
        p, n = _on(bvh, 0.0, f.neck - 0.045, 0.012)
        sphere(0.026, p, mat("tie", c["tie_col"], rough=0.5), seg=10, rings=6, scale=(1.1, 0.9, 0.6), rot=_facing(n), name="tie_knot")
        for s in (1, -1):
            _decal(bvh, [(s * 0.08, f.neck - 0.02), (s * 0.15, f.neck - 0.08), (s * 0.12, f.neck - 0.14), (s * 0.06, f.neck - 0.18), (s * 0.01, f.neck - 0.26), (s * 0.05, f.neck - 0.06)], lapel, out=0.005, name="lapel", rings=3)
        for j in range(2):
            p, n = _on(bvh, 0.012, f.neck - 0.34 - j * 0.1, 0.006)
            sphere(0.014, p, mat("suit_button", "#2a1d14", rough=0.4), seg=8, rings=6, scale=(1, 1, 0.5), rot=_facing(n), name="button")
    elif k == "braces":
        red = mat("braces", c["braces_col"], rough=0.55)
        for s in (1, -1):
            path = [(s * 0.1, y0 + 0.13, 0.4), (s * 0.12, f.torso_y + 0.05, 0.4), (s * 0.135, f.shoulder_y + 0.04, 0.2),
                    (s * 0.14, f.shoulder_y + 0.14, 0.0), (s * 0.135, f.shoulder_y + 0.04, -0.2), (s * 0.08, f.torso_y, -0.4), (s * 0.03, y0 + 0.13, -0.4)]
            _band(bvh, path, lambda p: (p.x * 0.4, min(p.y, f.shoulder_y - 0.06), 0.0), 0.038, 0.008, red, name="brace")
            p, n = _on(bvh, s * 0.1, y0 + 0.14, 0.012)
            box((0.03, 0.03, 0.01), p, mat("clip", "#c9cfd3", rough=0.3, metal=0.3), bevel=0.003, rot=_facing(n), name="brace_clip")
        nk = mat("neckerchief", c["scarf_col"], rough=0.6)
        _decal(bvh, [(-0.11, f.neck - 0.02), (0.11, f.neck - 0.02), (0.0, f.neck - 0.17)], nk, out=0.008, name="neckerchief", rings=3)
        p, n = _on(bvh, 0.0, f.neck - 0.03, 0.02)
        sphere(0.03, p, nk, seg=10, rings=6, scale=(1.3, 0.8, 0.7), rot=_facing(n), name="scarf_knot")
        torus(0.104, 0.026, (0, f.neck - 0.01, 0.0), nk, seg=22, rseg=6, rot=(-8, 0, 0), name="scarf_round")
    elif k == "puffer":
        seam = mat("puffer_seam", _mix(c["top_col"], "#6b4a00", 0.3), rough=0.6)
        for j in range(5):
            _ring(bvh, y0 + 0.06 + j * 0.115, 0, 0, -0.002, 0.009, seam, name="quilt")
        _decal(bvh, [(-0.012, f.neck - 0.03), (0.012, f.neck - 0.03), (0.012, y0 + 0.02), (-0.012, y0 + 0.02)], mat("zip", "#3a3a3e", rough=0.5), out=0.004, name="zip", rings=2)
        lathe([(1.0, -0.5), (1.12, -0.25), (1.12, 0.25), (1.0, 0.5)], (0, f.neck - 0.01, 0.0), top_m, seg=28, scale=(0.105, 0.09, 0.1), name="high_collar")
    elif k == "chef_jacket":
        flap = mat("jacket_flap", "#fbfaf6", rough=0.7)
        _decal(bvh, [(-0.04, f.neck - 0.06), (0.2, f.neck - 0.1), (0.21, y0 + 0.05), (-0.04, y0 + 0.05)], flap, out=0.004, name="flap", rings=3)
        edge = [_on(bvh, -0.04, y, 0.007)[0] for y in [f.neck - 0.06 - (f.neck - 0.06 - y0 - 0.05) * t / 8 for t in range(9)]]
        tube(edge, 0.005, mat("jacket_edge", "#d9d4c8", rough=0.7), seg=6, name="flap_edge")
        bt = mat("jacket_button", "#bdb4a6", rough=0.5)
        for bx in (-0.1, 0.12):
            for j in range(3):
                p, n = _on(bvh, bx, f.neck - 0.17 - j * 0.12, 0.008)
                sphere(0.017, p, bt, seg=10, rings=6, scale=(1, 1, 0.55), rot=_facing(n), name="button")
        torus(0.1, 0.026, (0, f.neck - 0.005, 0.004), mat("collar", "#f8f6f1", rough=0.75), seg=22, rseg=6, rot=(-6, 0, 0), name="stand_collar")
        nk = mat("neckerchief", c["scarf_col"], rough=0.6)
        _decal(bvh, [(-0.09, f.neck - 0.03), (0.09, f.neck - 0.03), (0.0, f.neck - 0.14)], nk, out=0.009, name="neckerchief", rings=3)
        p, n = _on(bvh, 0.0, f.neck - 0.035, 0.022)
        sphere(0.028, p, nk, seg=10, rings=6, scale=(1.3, 0.8, 0.7), rot=_facing(n), name="scarf_knot")
    if c.get("apron"):
        ap = mat("apron", c.get("apron_col", "#efe6d4"), rough=0.8)
        flour = mat("flour", "#fbf9f3", rough=0.9)
        _decal(bvh, [(-0.12, f.neck - 0.12), (0.12, f.neck - 0.12), (0.16, y0 + 0.13), (-0.16, y0 + 0.13)], ap, out=0.005, name="apron_bib", rings=3)
        for s in (1, -1):
            path = [(s * 0.11, f.neck - 0.11, 0.4), (s * 0.12, f.shoulder_y + 0.06, 0.25), (s * 0.13, f.shoulder_y + 0.14, 0.0),
                    (s * 0.12, f.shoulder_y + 0.04, -0.25), (s * 0.1, f.torso_y, -0.4)]
            _band(bvh, path, lambda p: (p.x * 0.4, min(p.y, f.shoulder_y - 0.06), 0.0), 0.028, 0.006, ap, name="apron_strap")
        _ring(bvh, y0 + 0.13, 0, 0, 0.004, 0.012, ap, name="apron_tie")
        # the skirt of the apron, curving round the front of the legs to the knees (outer and inner faces)
        top_r, bot_r = 0.215 * f.w + 0.03, 0.25 * f.w + 0.04
        prof = [(top_r, 0.0), (bot_r, -(f.hip + 0.13 - f.knee - 0.02))]
        lathe(prof, (0, f.hip + 0.13, 0.0), ap, seg=14, a0=-62, arc=124, scale=(1.0, 1.0, 0.9 * f.d), name="apron")
        lathe([(top_r - 0.006, 0.0), (bot_r - 0.006, -(f.hip + 0.13 - f.knee - 0.02))], (0, f.hip + 0.13, 0.0), ap, seg=14, a0=-62, arc=124, scale=(1.0, 1.0, 0.9 * f.d), flip=True, name="apron_back")
        for (fx, fy) in ((0.05, f.torso_y - 0.05), (-0.08, f.torso_y - 0.15), (0.1, y0 + 0.2), (-0.03, f.neck - 0.2)):
            p, n = _on(bvh, fx, fy, 0.007)
            sphere(0.022, p, flour, seg=10, rings=6, scale=(1.3, 0.9, 0.2), rot=_facing(n), name="flour")
    # the backpack, its straps over the shoulders and round under the arms, and a chest strap
    if c.get("backpack"):
        bp = mat("backpack", c["pack_col"], rough=0.6)
        bpd = mat("backpack_dark", _mix(c["pack_col"], "#0b2210", 0.35), rough=0.6)
        zb = -0.2 * f.d - 0.13
        box((0.42, 0.48, 0.24), (0, f.torso_y + 0.1, zb), bp, bevel=0.06, name="backpack")
        box((0.32, 0.2, 0.06), (0, f.torso_y + 0.0, zb - 0.135), bpd, bevel=0.03, name="pack_pocket")
        box((0.4, 0.13, 0.25), (0, f.torso_y + 0.3, zb + 0.005), bpd, bevel=0.05, name="pack_lid")
        text("RAPIDO", (0, f.torso_y - 0.02, zb - 0.167), mat("bag_text", "#ffffff", rough=0.5), size=0.05, depth=0.003, rot=(0, 180, 0), name="bag_text")
        strap = mat("pack_strap", "#2b2f33", rough=0.6)
        for s in (1, -1):
            path = [(s * 0.13, f.shoulder_y + 0.0, -0.4), (s * 0.135, f.shoulder_y + 0.1, -0.3), (s * 0.14, f.shoulder_y + 0.18, 0.0),
                    (s * 0.14, f.shoulder_y + 0.08, 0.3), (s * 0.145, f.torso_y + 0.05, 0.4), (s * 0.16, f.torso_y - 0.12, 0.4),
                    (s * 0.24, f.torso_y - 0.18, 0.25), (s * 0.3, f.torso_y - 0.16, 0.0), (s * 0.22, f.torso_y - 0.14, -0.3)]
            _band(bvh, path, lambda p: (p.x * 0.3, min(p.y, f.shoulder_y - 0.08), 0.0), 0.045, 0.012, strap, name="pack_strap")
        cs = [(-0.16, f.torso_y + 0.12, 0.4), (0.0, f.torso_y + 0.13, 0.4), (0.16, f.torso_y + 0.12, 0.4)]
        _band(bvh, cs, lambda p: (p.x * 0.3, p.y, 0.0), 0.022, 0.008, strap, name="chest_strap", per=4)
        p, n = _on(bvh, 0.0, f.torso_y + 0.13, 0.018)
        box((0.045, 0.03, 0.012), p, mat("buckle_black", "#151515", rough=0.4), bevel=0.004, rot=_facing(n), name="chest_buckle")


def _quilt_arms(f, c):
    """a puffer's sleeves are quilted too: rings round the upper arm and forearm (they ride on the joints)"""
    seam = mat("puffer_seam", _mix(c["top_col"], "#6b4a00", 0.3), rough=0.6)
    for s in (1, -1):
        tag = "l" if s > 0 else "r"
        shj = bpy.data.objects["shoulder_" + tag]
        elj = bpy.data.objects["elbow_" + tag]
        sh = Vector((s * f.sh[0], f.sh[1], f.sh[2]))
        el = Vector((s * f.el[0], f.el[1], f.el[2]))
        wr = Vector((s * f.wr[0], f.wr[1], f.wr[2]))
        for (a, b, joint, at, rr) in ((sh, el, shj, sh, 0.075), (el, wr, elj, el, 0.066)):
            tilt = math.degrees(math.atan2(b.x - a.x, a.y - b.y))
            for t in (0.4, 0.75):
                p = a.lerp(b, t)
                o = torus(rr, 0.008, tuple(p), seam, seg=16, rseg=4, rot=(0, 0, tilt), name="arm_quilt")
                o.data.transform(Matrix.Translation(-at))
                o.parent = joint


def _person(c):
    """a person, built at full size, then grown by c["k"] about the feet"""
    f = _frame(**c.get("frame", {}))
    skin_m = mat("skin", SKIN[c["skin"]], rough=0.62)
    torso, top_m = _body(f, c)
    for s in (1, -1):
        _arm(f, s, c, top_m, skin_m)
    if c["top"] == "puffer": _quilt_arms(f, c)
    _clothes(f, c, torso, top_m)
    # the head on the neck: the head, its face, hair or a hat
    neck = empty("neck", (0, f.neck, 0))
    before = set(bpy.context.scene.objects)
    head = _head(f, c)
    _face(f, c, head, mat("hair", c["hair_col"], rough=0.72))
    _hair(f, c, head)
    for o in [o for o in bpy.context.scene.objects if o not in before and o.type == "MESH"]:
        o.data.transform(Matrix.Translation(Vector((0, -f.neck, 0))))
        o.parent = neck
    for s in (1, -1):
        _leg(f, s, c)
    k = c.get("k", 1.0)
    if k != 1.0:              # grow (or shrink) the whole figure about its feet, joints and all
        for o in bpy.context.scene.objects:
            if o.type == "MESH": o.data.transform(Matrix.Scale(k, 4))
            o.location = o.location * k
    # one mesh per joint (its parts keep their materials): a hand is one mesh, not twelve, so a full dining room
    # costs far fewer draw calls on a phone. The loose body parts are joined into one by the build as usual.
    groups = {}
    for o in list(bpy.context.scene.objects):
        if o.type == "MESH" and o.parent is not None and o.parent.type == "EMPTY":
            groups.setdefault(o.parent.name, []).append(o)
    for jn, objs in groups.items():
        if len(objs) > 1: join(objs, jn + "_mesh")


# the cast (customer.0 is a kid: the game never has a kid order alone at the hatch)
PEOPLE = {
    "customer.0": dict(k=0.74, frame=dict(hip=0.5, w=0.92, d=0.95, hk=1.22), skin="rosy",
                       hair="kid_cap", hair_col="#6a4128", hat_col="#d9442e", glasses=True,
                       top="hoodie", top_col="#3f74c9", long_top=True, sleeves="long", cuff_col="#365f9f",
                       legs="shorts", legs_col="#4a5163", shoes="sneaker", shoe_col="#5b8fd6"),
    "customer.1": dict(k=0.95, frame=dict(hip=0.55, w=1.12, d=1.08, belly=0.45), skin="fair",
                       hair="granny", hair_col="#d2d4d8", eyes="happy", earrings=True, brow_col="#b9bcc2",
                       top="cardigan", top_col="#ffffff", top_tex="floral", top_uvs=0.24, collar_col="#f3e6cc", long_top=True,
                       sleeves="long", sleeve_col="#ffffff", sleeve_tex="floral", cuff_col="#f3e6cc",
                       legs="skirt", legs_col="#e8b8a0", skirt_col="#ea9fb0", shoes="flat", shoe_col="#7a4a2e"),
    "customer.2": dict(k=1.0, frame=dict(hip=0.58, w=0.94), skin="brown", hoops=True,
                       hair="ponytail", hair_col="#1f1714", tie_col="#f2a33a",
                       top="tee", top_col="#7fcfb4", collar_col="#6ab89e", sleeves="long", cuff_col="#6ab89e",
                       legs="trousers", legs_col="#ffffff", legs_tex="denim", rolled=True, shoes="sneaker", shoe_col="#f2f2ee"),
    "customer.3": dict(k=1.0, frame=dict(hip=0.6, w=0.95), skin="warm",
                       hair="beanie", hair_col="#8a4fc4", hat_col="#5a5d63", brow_col="#5e3a8a",
                       top="varsity", top_col="#2f7a45", sleeve_col="#efe6d0", under_col="#8a5bc0", sleeves="long", cuff_col="#2f7a45",
                       cuff_stripes=["#efe6d0"], legs="trousers", legs_col="#5a4136", shoes="sneaker", shoe_col="#b48ad6"),
    "customer.4": dict(k=1.04, frame=dict(hip=0.66, w=0.96, d=0.92), skin="tan",
                       hair="swept", hair_col="#5a3a24",
                       top="suit", top_col="#7a5a44", tie_col="#3d4552", long_top=True, sleeves="long", cuff_col="#f5f2ea",
                       legs="trousers", legs_col="#6e5240", shoes="leather", shoe_col="#5a3622", mouth_w=0.9),
    "customer.5": dict(k=1.0, frame=dict(hip=0.56, w=1.1, d=1.05, belly=1.0), skin="warm",
                       hair="papa", hair_col="#2b1d16", eyes="happy", moustache=True, mouth_w=0.75, mouth_d=0.8,
                       top="braces", top_col="#f4ecdd", braces_col="#c8402c", scarf_col="#d8402e", sleeves="short",
                       legs="trousers", legs_col="#ffffff", legs_tex="check_bw", legs_uvs=0.16, shoes="leather", shoe_col="#5a3622"),
    # the crew at Bella Napoli: Marco the boss, Luca the junior
    "staff.marco": dict(k=1.04, frame=dict(hip=0.56, w=1.12, d=1.06, belly=1.0), skin="warm",
                        hair="chef", hair_col="#2b1d16", eyes="happy", moustache=True, mouth_w=0.8, mouth_d=0.85,
                        top="chef_jacket", top_col="#f8f6f1", long_top=True, sleeves="long", cuff_col="#d8402e", scarf_col="#d8402e",
                        rolling_pin="r", legs="trousers", legs_col="#ffffff", legs_tex="check_bw", legs_uvs=0.16, shoes="leather", shoe_col="#4a2e1c"),
    "staff.luca": dict(k=0.98, frame=dict(hip=0.57, w=0.95), skin="fair", freckles=True,
                       hair="paper_hat", hair_col="#e0782e", brow_col="#c4642a",
                       top="tee", top_col="#ffffff", top_tex="stripes_ginger", top_uvs=0.11, collar_col="#ea7a3c", sleeves="short", apron=True,
                       legs="trousers", legs_col="#ffffff", legs_tex="denim", rolled=True, shoes="sneaker", shoe_col="#8a7a6a"),
    "rider": dict(k=1.0, frame=dict(hip=0.6, w=1.0), skin="warm",
                  hair="helmet", hair_col="#6b4428", hat_col="#e0453a",
                  top="puffer", top_col="#f2be2e", sleeves="long", cuff_col="#d9a51f", backpack=True, pack_col="#4c9a52", phone="r",
                  legs="trousers", legs_col="#ffffff", legs_tex="denim_dark", rolled=True, rolled_col="#6f86a6", shoes="sneaker", shoe_col="#e0453a"),
}


for _key, _c in PEOPLE.items():
    model(_key, c=_c)(_person)


def _hand(side, pose="open"):
    """a chunky cartoon hand (no arm), palm down, pointing -Z, fingertips at the origin (side 1 = right hand).
    pose: "open" (pressing and stretching dough), "pinch" (finger and thumb together, holding a topping),
    "grip" (a fist round a handle: the ladle, the peel).
    The palm and wrist are one soft shape; each finger is its own rounded tube curling slightly down, so they read
    as separate fingers from above; nails on the tips; the wrist rounded off."""
    skin = mat("skin", "#efbd96", rough=0.55)
    nail = mat("nail", "#fbe3d6", rough=0.35)
    s = side
    # palm, the knuckle ridge, the thumb's root and a rounded wrist, blended (just the hand: no forearm or sleeve to
    # get between you and the pizza)
    blobs([("ellipsoid", (0.0, 0.0, 0.118), 0.056, (1.0, 0.45, 0.95)),
           ("ellipsoid", (0.0, 0.004, 0.08), 0.05, (1.0, 0.36, 0.5)),
           ("ellipsoid", (-0.046 * s, -0.004, 0.122), 0.026, (1.0, 0.8, 1.3)),
           ("ellipsoid", (0.004 * s, 0.006, 0.168), 0.042, (0.95, 0.62, 0.8))], skin, res=0.005, name="palm", tris=1000)
    fingers = [(-0.034, 0.012, 0.075), (-0.0115, 0.0126, 0.083), (0.0115, 0.012, 0.078), (0.032, 0.0106, 0.063)]   # chunky
    for k, (fx, r, length) in enumerate(fingers):
        x0 = fx * s
        z0 = 0.078
        curl = pose == "grip" or (pose == "pinch" and k > 0)
        if curl:            # curled under the palm
            pts = [(x0, 0.007, z0), (x0 * 1.03, -0.012, z0 - 0.032), (x0 * 1.03, -0.036, z0 - 0.02), (x0 * 1.02, -0.04, z0 + 0.006)]
        elif pose == "pinch":   # the index finger reaching down to meet the thumb
            pts = [(x0, 0.007, z0), (x0 * 1.02, 0.0, z0 - length * 0.5), (x0 * 0.85, -0.012, z0 - length * 0.82), (x0 * 0.7, -0.02, z0 - length + r)]
        else:
            pts = [(x0, 0.007, z0), (x0 * 1.1, 0.004, z0 - length * 0.45), (x0 * 1.22, -0.006, z0 - length * 0.8), (x0 * 1.26, -0.013, z0 - length + r)]
        tube(pts, r, skin, seg=10, radii=[r * 1.05, r, r * 0.97, r * 0.93], caps=False, name="finger")
        tip = pts[-1]
        sphere(r * 0.93, tip, skin, seg=10, rings=6, name="fingertip")
        if not curl:
            sphere(r * 0.6, (tip[0], tip[1] + r * 0.62, tip[2] - r * 0.15), nail, seg=10, rings=5, scale=(1.0, 0.3, 1.15), name="nail")
        sphere(r * 1.08, pts[0], skin, seg=10, rings=6, name="knuckle")
    # the thumb, along the inside, pointing forward and in
    th = [(-0.05 * s, -0.004, 0.115), (-0.066 * s, -0.01, 0.088), (-0.07 * s, -0.013, 0.064)]
    if pose == "pinch":
        th = [(-0.05 * s, -0.004, 0.115), (-0.054 * s, -0.014, 0.066), (-0.034 * s, -0.022, 0.03)]
    elif pose == "grip":
        th = [(-0.05 * s, -0.004, 0.115), (-0.046 * s, -0.022, 0.085), (-0.022 * s, -0.034, 0.068)]
    tube(th, 0.0135, skin, seg=10, radii=[0.0145, 0.0135, 0.0125], caps=False, name="thumb")
    sphere(0.0125, th[-1], skin, seg=10, rings=6, name="thumb_tip")
    sphere(0.008, (th[-1][0], th[-1][1] + 0.008, th[-1][2] - 0.002), nail, seg=10, rings=5, scale=(1.0, 0.3, 1.15), name="nail")


model("hand.right", side=1)(_hand)
model("hand.left", side=-1)(_hand)
for _pose in ("pinch", "grip"):
    model("hand.right." + _pose, side=1, pose=_pose)(_hand)
    model("hand.left." + _pose, side=-1, pose=_pose)(_hand)
