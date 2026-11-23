"""Build Crust Empire's 3D models.

    blender -b --factory-startup --python-exit-code 1 --python tools/models/build.py -- all
    blender -b --factory-startup --python-exit-code 1 --python tools/models/build.py -- counter oven.wood

Each key is written to assets/models/fp-<key with dots as dashes>.glb, where the game picks it up
(Art.model("fp.<key>")). See ART_KEYS.md for what each key is and where it stands in the room."""
import os
import sys
import traceback

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lib
from common import MODELS
import rooms, fixtures  # noqa: F401  (registering the models)
for extra in ("props", "people"):
    if os.path.exists(os.path.join(os.path.dirname(os.path.abspath(__file__)), extra + ".py")):
        __import__(extra)

import bpy
from mathutils import Vector
from common import PLACES

# baking the painted-in shadows: how far occlusion reaches, and how finely big faces are cut to hold it
BAKE = {"room.van": dict(dist=0.45, max_len=0.42), "room.kitchen": dict(dist=0.45, max_len=0.42),
        "dining": dict(dist=0.9, max_len=1.0), "street": dict(dist=1.2, max_len=2.5)}


def _bake_opts(key, objs):
    if key in BAKE: return BAKE[key]
    lo = Vector((1e9,) * 3); hi = -lo
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
    size = (hi - lo).length
    return dict(dist=max(0.04, min(0.4, size * 0.22)), max_len=max(0.06, min(0.35, size / 6.0)))


def _occluders(key):
    """stand the fixtures in a room while it bakes, so the floor and walls darken round them"""
    before = set(bpy.context.scene.objects)
    fixtures_ = ["counter", "counter.side", "prep", "oven.electric" if key == "room.van" else "oven.wood"]
    for f in fixtures_:
        fn, kw = MODELS[f]
        fn(**kw)
    for name, pos in PLACES:
        if name == "freezer" and key == "room.van": continue
        mark = set(bpy.context.scene.objects)
        fn, kw = MODELS[name]
        fn(**kw)
        for o in set(bpy.context.scene.objects) - mark:
            if o.parent is None: o.location += Vector(pos)
    return [o for o in bpy.context.scene.objects if o not in before]


args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
keys = sorted(MODELS) if not args or args == ["all"] else args
failed = []
for k in keys:
    if k not in MODELS:
        print("UNKNOWN KEY", k)
        failed.append(k)
        continue
    lib.reset()
    fn, kw = MODELS[k]
    try:
        fn(**kw)
        lib.finish(keep=getattr(fn, "keep", ()))
        targets = [o for o in bpy.context.scene.objects if o.type == "MESH"]
        occ = _occluders(k) if k in ("room.van", "room.kitchen") else []
        lib.bake_ao(targets, **_bake_opts(k, targets))
        if getattr(fn, "after", None): fn.after(**kw)      # e.g. soot painted inside an oven, over its baked shadows
        for o in occ: bpy.data.objects.remove(o)
        lib.flatten()                                       # plain colours into the vertex colours: fewer draw calls
        lib.export(k)
    except Exception:
        traceback.print_exc()
        failed.append(k)
print("BUILD DONE", len(keys) - len(failed), "ok", ("FAILED: " + " ".join(failed)) if failed else "")
if failed:
    raise RuntimeError("models failed to build: " + " ".join(failed))       # with --python-exit-code 1, exit 1
