# Working on Crust Empire

## 3D models (Blender)

- Models are built only by the scripts in `tools/models/` (see `tools/models/README.md`), run headless:
  `blender -b --factory-startup --python-exit-code 1 --python tools/models/build.py -- <keys|all>`.
  `--python-exit-code 1` must come before `--python`, or Blender ignores it and a failure still exits 0.
- Before reporting any model or scene change as done, render the 4-view diagnostic contact sheet (front, side, top,
  three-quarter perspective) to `/tmp/preview.png`:
  `xvfb-run -a blender -b --factory-startup --python-exit-code 1 --python tools/models/preview.py -- <keys> scene.van scene.kitchen`
  Look at the rendered PNG yourself and check for floating parts, inverted normals (holes: back faces are culled),
  clipping and broken framing. The script must exit 0 (no FLOAT or FLIP). Iterate until it looks right.
- Then import into Godot (`godot --headless --path . --import`) and check the models in in-game screenshots.
