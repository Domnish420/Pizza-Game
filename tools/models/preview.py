"""Diagnostic contact sheets for the generated models.

    xvfb-run -a blender -b --factory-startup --python-exit-code 1 --python tools/models/preview.py -- counter oven.wood
    xvfb-run -a blender -b --factory-startup --python-exit-code 1 --python tools/models/preview.py -- all

(--python-exit-code has to come before --python: Blender reads its arguments in order and runs the script as soon
as it reaches --python.)

For each key it imports the exported model (what the game will load), checks it, and renders four views - front,
side, top and a three-quarter perspective - with Workbench into one sheet: /tmp/previews/<key>.png. Two more keys
put the models together the way the game does: `scene.van` (the van, the street and every prop where the game
places it, customers at the hatch) and `scene.kitchen` (the restaurant kitchen and dining room, wood oven, seated
customers). `all` does every model and both scenes. The last sheet is also written to /tmp/preview.png.

What it checks, and how to read the sheets:
- Back faces are culled, as they are in the game, so a face pointing the wrong way shows as a hole.
- FLIP: a closed shell whose normals point inwards.
- FLOAT: a group of parts that touches nothing else and does not reach the ground. Parts that hang on a wall,
  door or rail belonging to another model are only allowed to float in their own sheet (MOUNTED); in the scene
  sheets everything has to be held up by something.
- Rooms and scenes are drawn as sections (the front view cuts the nearest wall, the side view the nearest wall,
  the top view the ceiling), and their three-quarter view is from a top corner inside the room.
The script exits with code 1 if anything is FLIP or FLOAT (outside MOUNTED), or a model is missing.
"""
import bpy
import math
import os
import sys
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
MODELS = os.path.join(ROOT, "assets", "models")
OUTDIR = "/tmp/previews"
SIZE = 512
ROOMS = ("room.van", "room.kitchen", "dining")
# hung on a wall, a door, a rail or the ceiling of another model: may float in its own sheet
MOUNTED = {"counter": "ticket rail on the wall", "counter.side": "ladle rail and peel on the wall",
           "prep": "tablet, shelf and jars on the wall", "thermometer": "on the fridge door", "clipboard": "on the wall",
           "sign": "hangs in the hatch", "boxes": "wall shelf", "ticket": "clipped to the ticket rail",
           "ladle.*": "hangs on the ladle rail", "hand.*": "held by the camera"}


def is_mounted(key):
    return key in MOUNTED or (key.split(".")[0] + ".*") in MOUNTED


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def g2b(p):
    """game coordinates (Y up, Z toward the player) to Blender's (Z up)"""
    return Vector((p[0], -p[2], p[1]))


def load(key, at=None, scale=None, yaw=0.0):
    """import a model; with `at`, place it there (game coordinates) the way the game does. Returns its objects."""
    base = os.path.join(MODELS, "fp-" + key.replace(".", "-"))
    for ext in (".glb", ".gltf"):
        if os.path.exists(base + ext):
            before = set(bpy.data.objects)
            bpy.ops.import_scene.gltf(filepath=base + ext)
            new = [o for o in bpy.data.objects if o not in before]
            if at is not None or scale is not None or yaw:
                holder = bpy.data.objects.new("at_" + key, None)
                bpy.context.scene.collection.objects.link(holder)
                holder.location = g2b(at or (0, 0, 0))
                holder.rotation_euler.z = yaw
                if scale is not None: holder.scale = Vector((scale[0], scale[2], scale[1]))
                for o in new:
                    if o.parent is None: o.parent = holder
                new.append(holder)
            return new
    print("NO MODEL", key)
    return None


def meshes():
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


# ---------------------------------------------------------------- checks

def islands():
    """every connected piece of every mesh, in world space: (lo[n,3], hi[n,3], closed[n], volume[n], tris[n])"""
    los, his, cl, vols, ns = [], [], [], [], []
    bpy.context.view_layer.update()
    for ob in meshes():
        me = ob.data
        me.calc_loop_triangles()
        nv = len(me.vertices)
        co = np.empty(nv * 3)
        me.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3)
        mw = np.array(ob.matrix_world)
        co = co @ mw[:3, :3].T + mw[:3, 3]
        nt = len(me.loop_triangles)
        tri = np.empty(nt * 3, dtype=np.int64)
        me.loop_triangles.foreach_get("vertices", tri)
        tri = tri.reshape(-1, 3)
        # glTF splits vertices at hard edges and seams: join them by position
        q = np.round(co, 5)
        _, vid = np.unique(q, axis=0, return_inverse=True)
        vid = vid.reshape(-1)
        nu = vid.max() + 1 if nv else 0
        pos = np.zeros((nu, 3))
        pos[vid] = co
        t = vid[tri]
        parent = np.arange(nu)

        def find(a):
            r = a
            while parent[r] != r: r = parent[r]
            while parent[a] != r:
                parent[a], a = r, parent[a]
            return r
        for a, b, c in t:
            ra, rb, rc = find(a), find(b), find(c)
            parent[rb] = ra
            parent[find(rc)] = ra
        roots = np.array([find(i) for i in range(nu)])
        troot = roots[t[:, 0]]
        for r in np.unique(troot):
            g = t[troot == r]
            p = pos[g.reshape(-1)]
            los.append(p.min(0)); his.append(p.max(0))
            v0, v1, v2 = pos[g[:, 0]], pos[g[:, 1]], pos[g[:, 2]]
            vols.append(float(np.einsum("ij,ij->i", v0, np.cross(v1, v2)).sum() / 6.0))
            e = np.sort(np.concatenate([g[:, [0, 1]], g[:, [1, 2]], g[:, [2, 0]]]), axis=1)
            _, cnt = np.unique(e, axis=0, return_counts=True)
            cl.append(bool((cnt == 2).all()))
            ns.append(len(g))
    return np.array(los).reshape(-1, 3), np.array(his).reshape(-1, 3), np.array(cl), np.array(vols), np.array(ns)


def check(key):
    lo, hi, closed, vol, ntri = islands()
    n = len(lo)
    tol = 0.004
    flipped = [(lo[i] + hi[i]) / 2 for i in range(n) if closed[i] and vol[i] < -1e-8]
    # group the parts that touch, then see which groups reach the ground
    comp = -np.ones(n, dtype=int)
    k = 0
    for s in range(n):
        if comp[s] >= 0: continue
        comp[s] = k
        stack = [s]
        while stack:
            i = stack.pop()
            touch = np.all(lo[i] <= hi + tol, axis=1) & np.all(lo <= hi[i] + tol, axis=1) & (comp < 0)
            for j in np.nonzero(touch)[0]:
                comp[j] = k
                stack.append(j)
        k += 1
    ground = lo[:, 2].min() if n else 0.0
    floating = []
    for c in range(k):
        m = comp == c
        if lo[m, 2].min() <= ground + tol: continue
        floating.append((lo[m].min(0), hi[m].max(0), int(m.sum())))
    mounted = is_mounted(key)
    print("CHECK %-16s %6d tris %5d parts %4d groups  FLOAT %d%s  FLIP %d" % (
        key, int(ntri.sum()), n, k, len(floating), " (MOUNTED: %s)" % MOUNTED.get(key, MOUNTED.get(key.split(".")[0] + ".*")) if mounted and floating else "", len(flipped)))
    # reported in game coordinates (x, y up, z toward the player)
    for (a, b, c) in floating[:10]:
        m = (a + b) / 2
        print("   FLOAT %3d parts round (%.2f, %.2f, %.2f), %.2f x %.2f x %.2f" % (c, m[0], m[2], -m[1], b[0] - a[0], b[2] - a[2], b[1] - a[1]))
    for p in flipped[:10]: print("   FLIP  near (%.2f, %.2f, %.2f)" % (p[0], p[2], -p[1]))
    return len(flipped) + (0 if mounted else len(floating))

# ---------------------------------------------------------------- rendering

def bounds(objs=None):
    lo = Vector((1e9, 1e9, 1e9)); hi = -lo
    for ob in (objs or meshes()):
        if ob.type != "MESH": continue
        for c in ob.bound_box:
            w = ob.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
    return lo, hi


def setup_scene():
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.resolution_x = SIZE
    sc.render.resolution_y = SIZE
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.color_type = "TEXTURE"
    sh.show_backface_culling = True
    sh.show_cavity = True
    sh.cavity_type = "WORLD"
    sh.show_object_outline = True
    sh.object_outline_color = (0.1, 0.1, 0.1)
    if sc.world is None: sc.world = bpy.data.worlds.new("w")
    sc.world.color = (0.33, 0.38, 0.45)
    sc.render.use_stamp = True
    for a in dir(sc.render):
        if a.startswith("use_stamp_") and a not in ("use_stamp_note", "use_stamp_labels"):
            try: setattr(sc.render, a, False)
            except Exception: pass
    sc.render.use_stamp_note = True
    sc.render.stamp_font_size = 18
    for m in bpy.data.materials:            # untextured materials show their base colour
        if m.use_nodes:
            m.diffuse_color = _base_colour(m)


def _base_colour(m):
    """a material's flat colour: the Base Color, or (with baked vertex colours, which the importer multiplies in
    through a mix node) the colour factor on that node"""
    b = m.node_tree.nodes.get("Principled BSDF")
    if b is None: return (0.8, 0.8, 0.8, 1.0)
    sock = b.inputs["Base Color"]
    if not sock.is_linked: return tuple(sock.default_value)
    seen, todo = set(), [sock.links[0].from_node]
    while todo:
        n = todo.pop()
        if n.name in seen: continue
        seen.add(n.name)
        if n.type == "RGB": return tuple(n.outputs[0].default_value)
        for i in n.inputs:
            if i.type == "RGBA" and not i.is_linked and i.enabled and tuple(i.default_value)[:3] != (0.5, 0.5, 0.5):
                return tuple(i.default_value)
            if i.is_linked: todo.append(i.links[0].from_node)
    return (0.8, 0.8, 0.8, 1.0)


def _aim(cam, d):
    """point the camera along -d (d points from the subject to the camera)"""
    if abs(d.z) > 0.999:
        cam.rotation_euler = (0.0, 0.0, 0.0)          # straight down, the far side (the game's -Z) at the top
    else:
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()


def view(name, cam_dir, lo, hi, label, ortho=True, section=0.0, inside=False):
    sc = bpy.context.scene
    centre = (lo + hi) / 2
    radius = (hi - lo).length / 2 + 1e-3
    d = Vector(cam_dir).normalized()
    cam = bpy.data.objects.new("cam_" + name, bpy.data.cameras.new("cam_" + name))
    sc.collection.objects.link(cam)
    cd = cam.data
    if ortho:
        dist = radius * 2.0
        cam.location = centre + d * dist
        _aim(cam, d)
        cd.type = "ORTHO"
        up = Vector((0, 1, 0)) if abs(d.z) > 0.999 else Vector((0, 0, 1))
        right = (-d).cross(up).normalized()
        upv = right.cross(-d).normalized()
        corners = [Vector((x, y, z)) for x in (lo.x, hi.x) for y in (lo.y, hi.y) for z in (lo.z, hi.z)]
        w = max(abs((c - centre).dot(right)) for c in corners) * 2
        h = max(abs((c - centre).dot(upv)) for c in corners) * 2
        cd.ortho_scale = max(w, h) * 1.06
        depth = max(abs((c - centre).dot(d)) for c in corners)
        cd.clip_start = max(0.001, dist - depth + section) if section else 0.001
        cd.clip_end = dist + radius * 4 + 60
    elif inside:
        # a camera in a top corner of the room, looking across to the far bottom corner
        c = (lo + hi) / 2
        eye = Vector((c.x, hi.y - 0.2, lo.z + (hi.z - lo.z) * 0.86))      # high at the back (the game's +Z)
        target = Vector((c.x, lo.y + (hi.y - lo.y) * 0.25, lo.z + (hi.z - lo.z) * 0.3))
        cam.location = eye
        cam.rotation_euler = (target - eye).to_track_quat("-Z", "Y").to_euler()
        cd.lens = 14
        cd.sensor_width = 36
        cd.clip_start = 0.02
        cd.clip_end = 200
    else:
        cd.lens = 50
        cd.sensor_width = 36
        fov = 2 * math.atan(18 / 50.0)
        cam.location = centre + d * (radius / math.sin(fov / 2) * 1.02)
        _aim(cam, d)
        cd.clip_start = 0.005
        cd.clip_end = radius * 8 + 60
    sc.camera = cam
    sc.render.stamp_note_text = label
    path = os.path.join(OUTDIR, "_%s.png" % name)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def sheet(title, paths, out):
    try:
        from PIL import Image, ImageDraw
        im = Image.new("RGB", (SIZE * 2, SIZE * 2 + 34), (24, 28, 32))
        for i, p in enumerate(paths):
            im.paste(Image.open(p).convert("RGB"), ((i % 2) * SIZE, 34 + (i // 2) * SIZE))
        dr = ImageDraw.Draw(im)
        dr.text((10, 10), title + "  -  front | side / top | three-quarter", fill=(240, 240, 240))
        dr.line([(SIZE, 34), (SIZE, SIZE * 2 + 34)], fill=(24, 28, 32), width=3)
        dr.line([(0, SIZE + 34), (SIZE * 2, SIZE + 34)], fill=(24, 28, 32), width=3)
        im.save(out)
    except ImportError:
        import shutil
        shutil.copy(paths[-1], out)


def render_sheet(key, lo, hi, room):
    setup_scene()
    span = hi - lo
    paths = [
        view("front", (0, -1, 0), lo, hi, "%s FRONT (from +Z)" % key, section=0.15 if room else 0.0),
        view("side", (1, 0, 0), lo, hi, "%s SIDE (from +X)" % key, section=0.15 if room else 0.0),
        view("top", (0, 0, 1), lo, hi, "%s TOP" % key, section=max(0.35, span.z * 0.15) if room else 0.0),
        view("persp", (0.75, -1.0, 0.7), lo, hi, "%s 3/4" % key, ortho=False, inside=room),
    ]
    out = os.path.join(OUTDIR, key + ".png")
    sheet("fp." + key if not key.startswith("scene") else key, paths, out)
    sheet("fp." + key if not key.startswith("scene") else key, paths, "/tmp/preview.png")
    print("SHEET", out)


def preview(key):
    clear()
    if load(key) is None: return 1
    bad = check(key)
    lo, hi = bounds()
    render_sheet(key, lo, hi, key in ROOMS)
    return bad

# ---------------------------------------------------------------- the scenes, put together as the game does

def _seat(objs, ang):
    """bend a customer's joints to sit, as FPWorld._arrange does"""
    for o in objs:
        base = o.name.split(".")[0]
        if base in ("hip_l", "hip_r", "knee_l", "knee_r"):
            o.rotation_mode = "XYZ"                   # the glTF importer leaves objects in quaternion mode
            o.rotation_euler = (-math.pi / 2 if base.startswith("hip") else math.pi / 2, 0.0, 0.0)


def scene(name):
    clear()
    van = name == "scene.van"
    room = load("room.van" if van else "room.kitchen")
    if room is None: return 1
    load("street" if van else "dining")
    for k in ("counter", "counter.side", "prep"): load(k)
    load("oven.electric" if van else "oven.wood")
    if not van: load("logs", (1.12, 0.6, 0.72))
    for k, p in [("pass", (1.5, 0.92, -1.02)), ("bin", (-0.62, 0.92, -0.78)), ("sheeter", (-0.62, 0.92, -0.45)),
                 ("crates", (-1.2, 0, 0.75)), ("fridge", (-0.62, 0, 0.97)), ("thermometer", (-0.45, 1.45, 0.62)),
                 ("freezer", (1.3, 0, 1.08)), ("drystore", (0.42, 0, 1.08)), ("mop", (-1.28, 0, 0.25)),
                 ("spray", (0.62, 0.92, -0.52)), ("trapbox", (-1.3, 0, 1.12)), ("boxes", (1.32, 1.8, -1.0)),
                 ("bowl" if van else "mixer", (-1.38, 0.92, -1.0)), ("dough_trays", (1.47, 0.92, -0.38)),
                 ("clipboard", (-0.98, 1.55, -1.08)), ("sign", (0.58, 1.66, -1.06))]:
        if k == "freezer" and van: continue
        load(k, p)
    n = 6
    pw = 1.5 / n
    for i in range(n):
        load("pan", (-0.75 + pw * (i + 0.5), 0.99, -1.0), scale=(pw * 0.96 / 0.1, 1, 1))
    for i, oz in enumerate((1, 2, 3, 4)):
        load("ladle.%d" % oz, (0.9 + i * 0.11, 1.3, -1.02))
    for i in range(3):
        load("ticket", (-0.74 + i * 0.205, 1.82, -1.05))
    if van:
        load("customer.0", (-0.25, -0.42, -1.6))
        load("customer.3", (0.3, -0.42, -1.75))
        load("rider", (1.2, -0.42, -2.2))
    else:
        for t, (tx, tz) in enumerate([(-1.5, -4.0), (1.2, -5.5)]):
            load("table", (tx, 0, tz))
            for i, look in enumerate((1, 4) if t == 0 else (2, 5)):
                a = Vector((0.62, 0)).copy()
                ang = i * math.pi
                ax, az = math.cos(ang) * 0.62, math.sin(ang) * 0.62
                from people import HIP_Y, GROW
                objs = load("customer.%d" % look, (tx + ax, -(HIP_Y * GROW - 0.53), tz + az), yaw=math.atan2(-ax, -az))
                _seat(objs, ang)
    bad = check(name)
    lo, hi = bounds(room)                         # frame the room, not the whole street
    render_sheet(name, lo, hi, True)
    return bad


os.makedirs(OUTDIR, exist_ok=True)
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if not args or args == ["all"]:
    args = sorted(f[3:-5].replace("-", ".") for f in os.listdir(MODELS) if f.startswith("fp-") and f.endswith(".gltf"))
    args += ["scene.van", "scene.kitchen"]
problems = 0
for k in args:
    problems += scene(k) if k.startswith("scene.") else preview(k)
print("PREVIEW DONE", len(args), "sheets,", problems, "problems")
if problems:
    raise SystemExit(1)
