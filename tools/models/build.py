"""Build Crust Empire's 3D models.

    blender -b --factory-startup -P tools/models/build.py -- all
    blender -b --factory-startup -P tools/models/build.py -- counter oven.wood

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
        lib.finish(keep=kw.get("keep", ()) if False else getattr(fn, "keep", ()))
        lib.export(k)
    except Exception:
        traceback.print_exc()
        failed.append(k)
print("BUILD DONE", len(keys) - len(failed), "ok", ("FAILED: " + " ".join(failed)) if failed else "")
