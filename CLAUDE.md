# Working on Crust Empire

The owner makes the art and the calls on how the game should feel; Claude writes the code, builds the models and
keeps the tests green. `DESIGN.md` has the owner's vision and the art style: read it before changing how something
looks or plays. `ROADMAP.md` is what is built and what is next.

## Tools

`godot` (4.3), `blender` (4.0) and `gdlint` are installed by the cloud environment's setup script. If one is missing,
install it the same way: Godot 4.3 from the GitHub release into `/opt/godot` with a `godot` link in `/usr/local/bin`,
`apt-get install blender`, `pip install --break-system-packages "gdtoolkit==4.*"`.

## Tests

- `tests/run.sh [names]` runs the bots in `tests/` on a virtual screen (see `tests/README.md`). Before reporting a
  change as done, run the tests that cover it; before committing a change to service, the story, the rules or the
  HUD, run the whole suite. New behaviour gets a check in a test (extend one or add `tests/test_<name>.gd`).
- Look at the screenshots in `tests/out/<name>/` when a change is visual.
- `gdlint scripts/ tests/` must pass.

## Handing work over

After each finished piece of work: commit and push, zip the project (without `.git`, `.godot`, `tools/models/tex`,
`__pycache__` and `*.import`) and send the zip to the owner with a short summary of what changed.

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
