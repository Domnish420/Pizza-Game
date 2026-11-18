"""Shared helpers for building Crust Empire's 3D models in Blender, headless.

Everything is modelled directly in the game's own space: metres, Y up, the player at the origin facing -Z
(see ART_KEYS.md). The export keeps those axes (export_yup=False), so a model built here lands in the game
exactly where it was built, with no axis conversion to think about.

Shapes are made with bmesh (boxes with bevelled edges, lathed bowls and tubs, tubes along paths, metaball blobs
for anything soft), textures are generated with numpy (tiles, marble, wood, brushed steel, mosaic...), and every
model is exported as a single .glb into assets/models/, which the game loads by key through Art.model().
"""
import bpy
import bmesh
import math
import os
import numpy as np
from mathutils import Vector, Matrix, Euler

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "models")
TEX = os.path.join(HERE, "tex")

# The look (see REPLIT_BRIEF.md, "The art style"): chunky, rounded, toy-like props in warm ingredient colours,
# painted-in shadows (ambient occlusion baked into vertex colours), soft materials and no bump maps.
ROUND = [True]          # boxes get rounded edges unless a model turns it off (the far-away street does)

# ---------------------------------------------------------------- scene

def reset():
    """Empty the scene and every data block, ready for the next model."""
    for coll in (bpy.data.objects, bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.metaballs,
                 bpy.data.curves, bpy.data.fonts):
        for b in list(coll):
            if coll is bpy.data.fonts and b.name == "Bfont": continue
            try:
                coll.remove(b)
            except Exception:
                pass
    MATS.clear()
    ROUND[0] = True


def link(ob, parent=None):
    bpy.context.scene.collection.objects.link(ob)
    if parent is not None:
        ob.parent = parent
    return ob


def empty(name, pos=(0, 0, 0), parent=None):
    """A named point in the model (a joint or something the game looks up by name)."""
    ob = bpy.data.objects.new(name, None)
    ob.location = Vector(pos)
    return link(ob, parent)

# ---------------------------------------------------------------- materials and textures

MATS = {}


def _col(c):
    if isinstance(c, str):
        c = c.lstrip("#")
        rgb = [int(c[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
        a = int(c[6:8], 16) / 255.0 if len(c) >= 8 else 1.0
        c = rgb + [a]
    c = list(c)
    if len(c) == 3: c.append(1.0)
    # the colour values are sRGB; Blender's shader inputs are linear
    lin = [((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c[:3]]
    return lin + [c[3]]


def mat(name, col="#cccccc", rough=0.6, metal=0.0, tex=None, normal=None, uvs=1.0, emit=None, emit_k=2.0, alpha=None):
    """A material, made once per model. tex/normal name a generated texture (see TEXTURES); uvs is how many
    metres one repeat of the texture covers."""
    if name in MATS: return MATS[name]
    # toy-like: painted metal rather than mirror steel, nothing glassy-hard, no bump maps
    metal = min(metal, 0.3)
    rough = max(rough, 0.32) if alpha is None else rough
    normal = None
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = _col(col)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if tex:
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = texture(tex, "albedo")
        nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
    if normal:
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = texture(normal, "normal")
        t.image.colorspace_settings.name = "Non-Color"
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(t.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    if emit is not None:
        key = "Emission Color" if "Emission Color" in b.inputs else "Emission"
        b.inputs[key].default_value = _col(emit)
        b.inputs["Emission Strength"].default_value = emit_k
    if alpha is not None:
        b.inputs["Alpha"].default_value = alpha
        m.blend_method = "BLEND"
    m["uvs"] = uvs
    MATS[name] = m
    return m

# --- numpy texture generators (all tile seamlessly) ---

def _vnoise(n, cx, cy, seed):
    """tileable value noise, n x n pixels, cx x cy cells"""
    g = np.random.default_rng(seed).random((cy, cx))
    def axis(cells):
        t = np.arange(n) * cells / n
        i0 = np.floor(t).astype(int)
        f = t - i0
        return i0 % cells, (i0 + 1) % cells, f * f * (3 - 2 * f)
    x0, x1, fx = axis(cx)
    y0, y1, fy = axis(cy)
    a = g[y0][:, x0]; b = g[y0][:, x1]; c = g[y1][:, x0]; d = g[y1][:, x1]
    fx = fx[None, :]; fy = fy[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(n, base, octaves, seed, gain=0.5, sx=1, sy=1):
    s = np.zeros((n, n)); amp = 1.0; tot = 0.0
    for o in range(octaves):
        s += amp * _vnoise(n, base * sx * 2 ** o, base * sy * 2 ** o, seed + o * 17)
        tot += amp; amp *= gain
    return s / tot


def _rgb(hexs):
    return np.array([int(hexs.lstrip("#")[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def _grid(n):
    y, x = np.mgrid[0:n, 0:n] / n
    return x, y


def _soft(d, w):
    """0 at the line, 1 more than w away"""
    return np.clip(d / w, 0.0, 1.0)


def tex_tiles(n, nx, ny, col, grout, var, seed, offset_rows=False, gw=0.012, jitter=0.06):
    x, y = _grid(n)
    row = np.floor(y * ny)
    xs = x * nx + (0.5 * (row % 2) if offset_rows else 0.0)
    col_i = np.floor(xs) % nx
    fx = xs - np.floor(xs); fy = y * ny - row
    d = np.minimum(np.minimum(fx, 1 - fx) / nx, np.minimum(fy, 1 - fy) / ny)
    h = _soft(d, gw)
    rng = np.random.default_rng(seed)
    tv = rng.normal(0, 1, (ny, nx))[row.astype(int) % ny, col_i.astype(int)]
    base = _rgb(col)[None, None, :] * (1 + var * tv[..., None]) * (1 + jitter * (fbm(n, 8, 3, seed + 3)[..., None] - 0.5))
    a = base * h[..., None] + _rgb(grout)[None, None, :] * (1 - h[..., None])
    return a, h


def tex_marble(n, seed):
    x, y = _grid(n)
    turb = fbm(n, 3, 5, seed)
    v = np.abs(np.sin((x * 2 + y * 3 + turb * 3.2) * math.pi))
    vein = np.clip(1 - v * 3.5, 0, 1) ** 2
    fine = np.clip(1 - np.abs(np.sin((x * 5 - y * 2 + fbm(n, 6, 4, seed + 9) * 4) * math.pi)) * 10, 0, 1)
    cloud = fbm(n, 4, 4, seed + 5)
    base = 0.94 + 0.05 * (cloud - 0.5)
    g = base - 0.16 * vein - 0.05 * fine
    a = np.stack([g * 1.0, g * 0.995, g * 0.985], -1)
    return a, 1 - 0.3 * vein


def tex_wood(n, seed, col="#9a6b3f", planks=0, plank_gap=0.004, var=0.12):
    x, y = _grid(n)
    warp = fbm(n, 4, 4, seed, sx=1, sy=4)
    pid = np.floor(x * planks) if planks else np.zeros_like(x)
    rng = np.random.default_rng(seed)
    pv = rng.normal(0, 1, max(planks, 1))[pid.astype(int)] if planks else 0
    rings = np.sin((x * 6 + warp * 1.2 + (pid * 3.7 if planks else 0)) * math.pi * 2)
    streak = fbm(n, 2, 4, seed + 4, sx=6, sy=1)
    grain = 0.95 + 0.025 * rings + 0.07 * (streak - 0.5)          # soft, painted-looking grain
    a = _rgb(col)[None, None, :] * grain[..., None] * (1 + var * (pv[..., None] if planks else 0))
    h = np.ones_like(x)
    if planks:
        fx = x * planks - pid
        d = np.minimum(fx, 1 - fx) / planks
        h = _soft(d, plank_gap)
        # stagger the plank ends
        ends = np.floor(y * 2 + rng.random(planks)[pid.astype(int)] * 2) % 2
        fy = (y * 2 + rng.random(planks)[pid.astype(int)] * 2) % 1
        h = np.minimum(h, _soft(np.minimum(fy, 1 - fy) / 2, plank_gap))
        a = a * (0.55 + 0.45 * h[..., None])
    return a, h


def tex_steel(n, seed):
    streak = fbm(n, 2, 5, seed, sx=1, sy=24)
    v = 0.74 + 0.07 * (streak - 0.5) + 0.02 * (fbm(n, 16, 2, seed + 2) - 0.5)
    a = np.stack([v * 0.98, v, v * 1.02], -1)
    return a, None


def tex_checker_plate(n, seed):
    cells = 8
    x, y = _grid(n)
    cx = x * cells; cy = y * cells
    ix = np.floor(cx); iy = np.floor(cy)
    fx = cx - ix - 0.5; fy = cy - iy - 0.5
    ang = np.where((ix + iy) % 2 == 0, math.pi / 4, -math.pi / 4)
    u = fx * np.cos(ang) + fy * np.sin(ang)
    v = -fx * np.sin(ang) + fy * np.cos(ang)
    h = np.clip(1 - (u / 0.36) ** 2 - (v / 0.09) ** 2, 0, 1) ** 0.5
    base = 0.62 + 0.05 * (fbm(n, 6, 3, seed) - 0.5)
    g = base + 0.12 * h
    return np.stack([g, g * 1.01, g * 1.03], -1), h


def tex_mosaic(n, seed, palette, cells=24, grout="#d8d2c4"):
    x, y = _grid(n)
    ix = np.floor(x * cells).astype(int); iy = np.floor(y * cells).astype(int)
    rng = np.random.default_rng(seed)
    pick = rng.integers(0, len(palette), (cells, cells))
    pal = np.array([_rgb(c) for c in palette])
    shade = 1 + 0.1 * rng.normal(0, 1, (cells, cells))
    a = pal[pick[iy, ix]] * shade[iy, ix][..., None]
    fx = x * cells - ix; fy = y * cells - iy
    d = np.minimum(np.minimum(fx, 1 - fx), np.minimum(fy, 1 - fy)) / cells
    h = _soft(d, 0.0035)
    a = a * h[..., None] + _rgb(grout)[None, None, :] * (1 - h[..., None])
    return a, h


def tex_asphalt(n, seed):
    v = 0.30 + 0.08 * (fbm(n, 32, 3, seed) - 0.5) + 0.10 * (np.random.default_rng(seed).random((n, n)) - 0.5)
    return np.stack([v, v, v * 1.03], -1), None


def tex_noise(n, seed, col, amt=0.08, base=6):
    v = 1 + amt * (fbm(n, base, 4, seed) - 0.5) * 2
    return _rgb(col)[None, None, :] * v[..., None], None


def tex_kraft(n, seed):
    fib = fbm(n, 4, 5, seed, sx=1, sy=6)
    v = 1 + 0.12 * (fib - 0.5) + 0.05 * (np.random.default_rng(seed).random((n, n)) - 0.5)
    return _rgb("#b48a5a")[None, None, :] * v[..., None], None


def tex_speckle(n, seed, col, dots, amt=0.25):
    rng = np.random.default_rng(seed)
    a = _rgb(col)[None, None, :] * (1 + 0.05 * (fbm(n, 6, 3, seed) - 0.5))[..., None]
    a = np.repeat(a, 1, 0)
    m = rng.random((n, n))
    for i, dc in enumerate(dots):
        sel = (m > i / len(dots) * amt + (1 - amt)) & (m <= (i + 1) / len(dots) * amt + (1 - amt))
        a[sel] = _rgb(dc)
    return a, None


def tex_checker(n, a, b, cells=4, var=0.03, seed=31):
    x, y = _grid(n)
    ix = np.floor(x * cells).astype(int); iy = np.floor(y * cells).astype(int)
    pick = ((ix + iy) % 2)[..., None]
    rng = np.random.default_rng(seed)
    shade = 1 + var * rng.normal(0, 1, (cells, cells))[iy, ix][..., None]
    c = (_rgb(a)[None, None, :] * (1 - pick) + _rgb(b)[None, None, :] * pick) * shade
    fx = x * cells - ix; fy = y * cells - iy
    d = np.minimum(np.minimum(fx, 1 - fx), np.minimum(fy, 1 - fy)) / cells
    return c * (0.82 + 0.18 * _soft(d, 0.004))[..., None], None


TEXTURES = {
    "checker": (256, lambda n: tex_checker(n, "#c8432f", "#f3ead6")),
    # name: (size, generator)
    "quarry": (256, lambda n: tex_tiles(n, 4, 4, "#c0603f", "#8c7a68", 0.05, 11, gw=0.006, jitter=0.04)),
    "subway": (256, lambda n: tex_tiles(n, 4, 8, "#f4f2ee", "#b9b5ad", 0.012, 12, offset_rows=True, gw=0.004, jitter=0.03)),
    "marble": (256, lambda n: tex_marble(n, 13)),
    "planks": (256, lambda n: tex_wood(n, 14, "#8a5c36", planks=5, plank_gap=0.003)),
    "oak": (128, lambda n: tex_wood(n, 15, "#a87a4c")),
    "walnut": (128, lambda n: tex_wood(n, 16, "#6a4428")),
    "steel": (256, lambda n: tex_steel(n, 17)),
    "plate": (256, lambda n: tex_checker_plate(n, 18)),
    "mosaic": (256, lambda n: tex_mosaic(n, 19, ["#b5472e", "#c8643a", "#9a3826", "#d9893f", "#7a2e22"])),
    "mosaic_blue": (256, lambda n: tex_mosaic(n, 20, ["#1f5f8b", "#2a7aa8", "#173f5f", "#3f9bc0", "#e8e2d0"])),
    "asphalt": (128, lambda n: tex_asphalt(n, 21)),
    "slabs": (256, lambda n: tex_tiles(n, 2, 2, "#a8a39a", "#5e5a54", 0.05, 22, gw=0.004, jitter=0.12)),
    "brick": (256, lambda n: tex_tiles(n, 4, 12, "#9c4a34", "#cfc6b8", 0.10, 23, offset_rows=True, gw=0.006, jitter=0.15)),
    "brick_yellow": (256, lambda n: tex_tiles(n, 4, 12, "#c9a46a", "#e6dfd2", 0.08, 24, offset_rows=True, gw=0.006, jitter=0.15)),
    "kraft": (128, lambda n: tex_kraft(n, 25)),
    "plaster": (128, lambda n: tex_noise(n, 26, "#e9e2d4", 0.04)),
    "cladding": (256, lambda n: tex_noise(n, 27, "#eef0ee", 0.025, 3)),
    "vinyl": (256, lambda n: tex_speckle(n, 28, "#5d6266", ["#7d8388", "#3d4246", "#9aa0a4"], 0.18)),
    "terrazzo": (256, lambda n: tex_speckle(n, 29, "#d9d3c7", ["#a49a8a", "#7a6e60", "#efe9de", "#b86b4b"], 0.3)),
    "stone": (128, lambda n: tex_noise(n, 30, "#b9b3a8", 0.12, 8)),
}


def texture(name, kind="albedo"):
    """a generated texture as a Blender image, cached on disk in tools/models/tex"""
    key = "%s_%s" % (name, kind)
    if key in bpy.data.images: return bpy.data.images[key]
    os.makedirs(TEX, exist_ok=True)
    path = os.path.join(TEX, key + ".jpg")
    if not os.path.exists(path):
        size, gen = TEXTURES[name]
        a, h = gen(size)
        if kind == "normal":
            if h is None: h = np.ones((size, size))
            k = 2.5
            dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * k
            dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * k
            nrm = np.stack([-dx, -dy, np.ones_like(h)], -1)
            nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
            a = nrm * 0.5 + 0.5
        else:
            a = np.clip(a, 0, 1)                 # an 8-bit image keeps the sRGB values as they are
        img = bpy.data.images.new(key, size, size, alpha=False)
        if kind == "normal": img.colorspace_settings.name = "Non-Color"
        rgba = np.concatenate([np.clip(a, 0, 1), np.ones((size, size, 1))], -1).astype(np.float32)
        img.pixels.foreach_set(rgba.ravel())
        img.filepath_raw = path
        img.file_format = "JPEG"
        bpy.context.scene.render.image_settings.quality = 88
        img.save()
        bpy.data.images.remove(img)
    img = bpy.data.images.load(path)
    img.name = key
    return img

# ---------------------------------------------------------------- shapes

def _rot(rot):
    """degrees, applied the way Godot does it (Y, then X, then Z)"""
    rx, ry, rz = [math.radians(a) for a in rot]
    return Matrix.Rotation(ry, 4, "Y") @ Matrix.Rotation(rx, 4, "X") @ Matrix.Rotation(rz, 4, "Z")


def _finish_bm(bm, name, m, pos, rot, smooth, parent, uv=True, scale=None):
    tm = Matrix.Translation(Vector(pos)) @ _rot(rot)
    if scale is not None: tm = tm @ Matrix.Diagonal(Vector(list(scale) + [1.0]))
    bm.transform(tm)
    bm.normal_update()
    if uv:
        uvl = bm.loops.layers.uv.verify()
        k = 1.0 / float(m.get("uvs", 1.0)) if m is not None else 1.0
        for f in bm.faces:
            n = f.normal
            ax = max(range(3), key=lambda i: abs(n[i]))
            for lp in f.loops:
                co = lp.vert.co
                if ax == 0: u, v = co.z * (-1 if n.x > 0 else 1), co.y
                elif ax == 1: u, v = co.x, co.z * (-1 if n.y > 0 else 1)
                else: u, v = co.x * (1 if n.z > 0 else -1), co.y
                lp[uvl].uv = (u * k, v * k)
    for f in bm.faces: f.smooth = smooth
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    if smooth:
        me.use_auto_smooth = True
        me.auto_smooth_angle = math.radians(50)
    if m is not None: me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    return link(ob, parent)


def box(size, pos, m, bevel=None, seg=2, rot=(0, 0, 0), name="box", parent=None):
    """a box; edges are rounded (chunky, toy-like) unless bevel=0 or the model turned ROUND off"""
    if bevel is None:
        thin = min(size)
        bevel = min(0.014, thin * 0.22) if ROUND[0] and thin >= 0.006 else 0.0
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=min(bevel, min(size) * 0.45), segments=seg, profile=0.5,
                        affect="EDGES", clamp_overlap=True)
    return _finish_bm(bm, name, m, pos, rot, bevel > 0, parent)


def cyl(r, h, pos, m, axis="y", seg=24, r2=None, bevel=0.0, rot=(0, 0, 0), name="cyl", parent=None, caps=True):
    """a cylinder (or a cone, with r2 for the top radius) centred on pos along an axis"""
    r2 = r if r2 is None else r2
    prof = []
    if caps: prof.append((0.0, -h / 2))
    if bevel > 0 and caps:
        prof += [(r - bevel, -h / 2), (r, -h / 2 + bevel), (r2, h / 2 - bevel), (r2 - bevel, h / 2)]
    else:
        prof += [(r, -h / 2), (r2, h / 2)]
    if caps: prof.append((0.0, h / 2))
    extra = {"x": (0, 0, -90), "z": (90, 0, 0), "y": (0, 0, 0)}[axis]
    ob = lathe(prof, (0, 0, 0), m, seg=seg, name=name, parent=None, smooth=True)
    ob.matrix_world = Matrix.Translation(Vector(pos)) @ _rot(rot) @ _rot(extra)
    _apply(ob)
    if parent is not None: ob.parent = parent
    return ob


def _apply(ob):
    me = ob.data
    me.transform(ob.matrix_world)
    ob.matrix_world = Matrix.Identity(4)


def lathe(profile, pos, m, seg=24, name="lathe", parent=None, smooth=True, rot=(0, 0, 0), arc=360.0, scale=None):
    """spin a profile of (radius, height) points round the Y axis: bowls, tubs, tins, buckets, bottles"""
    bm = bmesh.new()
    rings = []
    full = abs(arc - 360.0) < 0.01
    steps = seg if full else seg + 1
    for (r, y) in profile:
        ring = []
        if r <= 1e-6:
            ring = [bm.verts.new((0.0, y, 0.0))] * steps
        else:
            for i in range(steps):
                a = math.radians(arc) * i / seg
                ring.append(bm.verts.new((math.sin(a) * r, y, math.cos(a) * r)))
        rings.append(ring)
    for j in range(len(rings) - 1):
        A, B = rings[j], rings[j + 1]
        for i in range(seg):
            i2 = (i + 1) % steps
            vs = [A[i], A[i2], B[i2], B[i]]
            uniq = []
            for v in vs:
                if v not in uniq: uniq.append(v)
            if len(uniq) >= 3:
                try:
                    bm.faces.new(uniq)
                except ValueError:
                    pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _finish_bm(bm, name, m, pos, rot, smooth, parent, scale=scale)


def sphere(r, pos, m, seg=16, rings=10, scale=(1, 1, 1), rot=(0, 0, 0), name="sphere", parent=None):
    prof = [(math.sin(math.pi * i / rings) * r, -math.cos(math.pi * i / rings) * r) for i in range(rings + 1)]
    return lathe(prof, pos, m, seg=seg, name=name, parent=parent, rot=rot, scale=scale)


def tube(points, r, m, seg=10, name="tube", parent=None, caps=True, radii=None):
    """a round tube through a list of points (handles, pipes, wires, a mouse's tail)"""
    bm = bmesh.new()
    pts = [Vector(p) for p in points]
    rings = []
    prev_n = None
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        if prev_n is None:
            up = Vector((0, 1, 0)) if abs(t.y) < 0.9 else Vector((1, 0, 0))
            n = t.cross(up).normalized()
        else:
            n = (prev_n - t * prev_n.dot(t)).normalized()
        prev_n = n
        b = t.cross(n).normalized()
        rr = radii[i] if radii else r
        rings.append([bm.verts.new(p + (n * math.cos(2 * math.pi * k / seg) + b * math.sin(2 * math.pi * k / seg)) * rr) for k in range(seg)])
    for j in range(len(rings) - 1):
        for k in range(seg):
            bm.faces.new([rings[j][k], rings[j][(k + 1) % seg], rings[j + 1][(k + 1) % seg], rings[j + 1][k]])
    if caps:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _finish_bm(bm, name, m, (0, 0, 0), (0, 0, 0), True, parent)


def torus(R, r, pos, m, seg=24, rseg=8, rot=(0, 0, 0), name="torus", parent=None):
    pts = [(math.sin(2 * math.pi * i / seg) * R, 0.0, math.cos(2 * math.pi * i / seg) * R) for i in range(seg + 1)]
    ob = tube(pts, r, m, seg=rseg, name=name, caps=False)
    ob.matrix_world = Matrix.Translation(Vector(pos)) @ _rot(rot)
    _apply(ob)
    if parent is not None: ob.parent = parent
    return ob


def slab(poly, depth, pos, m, rot=(0, 0, 0), name="slab", parent=None, bevel=0.0):
    """a flat shape (a list of (x, y) points, anticlockwise) extruded depth along +Z, then placed"""
    bm = bmesh.new()
    vs = [bm.verts.new((x, y, 0.0)) for (x, y) in poly]
    f = bm.faces.new(vs)
    r = bmesh.ops.extrude_face_region(bm, geom=[f])
    top = [e for e in r["geom"] if isinstance(e, bmesh.types.BMVert)]
    for v in top: v.co.z += depth
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=2, profile=0.5, affect="EDGES", clamp_overlap=True)
    return _finish_bm(bm, name, m, pos, rot, bevel > 0, parent)


def text(s, pos, m, size=0.05, depth=0.002, rot=(0, 0, 0), align="CENTER", name="text", parent=None):
    """words as geometry, facing +Z (labels on sacks, tins, boxes)"""
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = s
    cu.size = size
    cu.extrude = depth / 2
    cu.align_x = align
    cu.align_y = "CENTER"
    cu.resolution_u = 3                     # few curve steps: letters stay cheap on a phone
    ob = bpy.data.objects.new(name, cu)
    link(ob)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    bpy.data.objects.remove(ob)
    me.materials.clear()
    me.materials.append(m)
    o2 = bpy.data.objects.new(name, me)
    link(o2)
    # Blender text lies in its XY plane facing +Z: that is already the game's front
    o2.matrix_world = Matrix.Translation(Vector(pos)) @ _rot(rot)
    _apply(o2)
    if parent is not None: o2.parent = parent
    return o2


_mb_n = [0]


def decimate(ob, tris):
    """cut a mesh down to about this many triangles, keeping its shape"""
    have = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    if have <= tris: return ob
    md = ob.modifiers.new("dec", "DECIMATE")
    md.ratio = tris / float(have)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    ob.modifiers.clear()
    old = ob.data
    ob.data = me
    bpy.data.meshes.remove(old)
    for p in me.polygons: p.use_smooth = True
    return ob


def blobs(elems, m, res=0.012, name="blob", parent=None, thresh=0.6, tris=None):
    """soft shapes from metaballs (hands, people, dough, a mouse): elems are
    ("ball", pos, radius), ("capsule", pos, radius, half_length, rot), ("ellipsoid", pos, radius, (sx, sy, sz), rot)"""
    _mb_n[0] += 1
    fam = "mb%d" % _mb_n[0]
    mb = bpy.data.metaballs.new(fam)
    mb.resolution = res
    mb.render_resolution = res
    mb.threshold = thresh
    ob = bpy.data.objects.new(fam, mb)
    link(ob)
    for e in elems:
        kind = e[0]
        el = mb.elements.new()
        el.co = Vector(e[1])
        el.radius = e[2] / 0.57             # a metaball's surface sits at about 0.57 of its radius: sizes here are the real ones
        el.stiffness = 2.0
        if kind == "capsule":
            el.type = "CAPSULE"
            el.size_x = e[3]                # half the length between the two ends' centres
            if len(e) > 4: el.rotation = _rot(e[4]).to_quaternion()
        elif kind == "ellipsoid":
            el.type = "ELLIPSOID"
            el.size_x, el.size_y, el.size_z = e[3]
            if len(e) > 4: el.rotation = _rot(e[4]).to_quaternion()
        else:
            el.type = "BALL"
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    bpy.data.objects.remove(ob)
    bpy.data.metaballs.remove(mb)
    me.name = name
    for p in me.polygons: p.use_smooth = True
    me.materials.append(m)
    o2 = bpy.data.objects.new(name, me)
    link(o2, parent)
    if tris: decimate(o2, tris)
    return o2


def densify(ob, max_len):
    """cut long edges so baked shading has vertices to live on (big walls and floors)"""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    for _ in range(7):
        long = [e for e in bm.edges if e.calc_length() > max_len]
        if not long: break
        bmesh.ops.subdivide_edges(bm, edges=long, cuts=1, use_grid_fill=True)
    bm.to_mesh(ob.data)
    bm.free()


def bake_ao(objs, dist=0.35, samples=32, tint=(0.56, 0.47, 0.44), strength=1.0, max_len=None, ground=True):
    """paint ambient occlusion into vertex colours (the game multiplies them into the colours): corners, creases and
    where things meet the ground go softly darker, in a warm tint rather than black. Everything else in the scene
    counts as an occluder, so a room can be baked with its fixtures standing in it."""
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = False          # this Blender has no denoiser: with it on, the bake fails silently (all black)
    if sc.world is None: sc.world = bpy.data.worlds.new("bake_world")
    sc.world.light_settings.distance = dist
    plane = None
    meshes = [o for o in objs if o is not None and o.type == "MESH"]
    if not meshes: return
    if ground:
        # a floor under the model, so its base darkens where it stands
        lo = min((o.matrix_world @ Vector(c)).y for o in meshes for c in o.bound_box)
        pm = bpy.data.meshes.new("bake_ground")
        s = 30.0
        pm.from_pydata([(-s, lo, -s), (s, lo, -s), (s, lo, s), (-s, lo, s)], [], [(0, 3, 2, 1)])
        plane = bpy.data.objects.new("bake_ground", pm)
        link(plane)
    for ob in meshes:
        if max_len: densify(ob, max_len)
        me = ob.data
        for a in list(me.color_attributes): me.color_attributes.remove(a)
        attr = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
        me.color_attributes.active_color = attr
        me.color_attributes.render_color_index = me.color_attributes.active_color_index
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.bake(type="AO", target="VERTEX_COLORS")
        attr = me.color_attributes["Col"]
        n = len(attr.data)
        c = np.empty(n * 4, dtype=np.float32)
        attr.data.foreach_get("color", c)
        c = c.reshape(-1, 4)
        if c[:, 0].max() <= 0.0:
            raise RuntimeError("ambient occlusion bake came out black for " + ob.name)
        ao = np.clip(c[:, 0], 0, 1) ** (0.8 * strength)
        t = np.array(tint, dtype=np.float32)
        rgb = t[None, :] + (1 - t[None, :]) * ao[:, None]
        c[:, :3] = rgb
        c[:, 3] = 1.0
        attr.data.foreach_set("color", c.ravel())
    if plane is not None:
        bpy.data.objects.remove(plane)
        bpy.data.meshes.remove(pm)


def join(objs, name):
    """merge meshes into one object (fewer draw calls on a phone)"""
    objs = [o for o in objs if o is not None and o.type == "MESH"]
    if not objs: return None
    if len(objs) == 1:
        objs[0].name = name
        return objs[0]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = name
    o.data.name = name
    return o


def mirror_x(ob, name=None):
    """a copy mirrored left to right"""
    me = ob.data.copy()
    me.transform(Matrix.Scale(-1, 4, Vector((1, 0, 0))))
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    o2 = bpy.data.objects.new(name or ob.name + "_m", me)
    return link(o2, ob.parent)


def finish(keep=()):
    """join every loose mesh into one, except named parts the game moves (and anything parented under them)"""
    loose = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.parent is None and o.name not in keep]
    if loose: join(loose, "model")


def export(key):
    os.makedirs(OUT, exist_ok=True)
    # .gltf + .bin, with the textures in one shared folder (assets/models/tex) so each is stored once, not once per model
    path = os.path.join(OUT, "fp-" + key.replace(".", "-") + ".gltf")
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            o.data.update()
    kw = dict(filepath=path, export_format="GLTF_SEPARATE", export_texture_dir="tex", export_yup=False, export_apply=True,
              use_selection=False, export_image_format="JPEG", export_cameras=False, export_lights=False, export_colors=True,
              export_animations=False, export_extras=False)
    try:
        bpy.ops.export_scene.gltf(**kw, export_jpeg_quality=85)
    except TypeError:
        bpy.ops.export_scene.gltf(**kw)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type == "MESH")
    size = os.path.getsize(path) + os.path.getsize(path[:-5] + ".bin")
    print("EXPORTED %-22s %6d tris %7.1f KB" % (key, tris, size / 1024.0))
    return path
