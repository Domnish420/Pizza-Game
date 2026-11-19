# Tests

Bots that play the real game and check it behaves. Each one loads the game's autoloads (and the main scene, when it
needs the screen), plays by calling the same methods a touch would, and checks what must hold. They need Godot 4.3
and a display; `run.sh` gives them a virtual one with `xvfb-run`.

```
tests/run.sh                      # all of them, quickest first
tests/run.sh day look_stick       # just these (the name is the part after test_)
GODOT=~/Godot_v4.3 tests/run.sh   # a Godot binary that is not on the PATH
```

Each bot's log and screenshots go to `tests/out/<name>/` (not committed). A bot passes when it exits 0, its last line
is `PASS: n checks, 0 failed`, and the log has no script errors or engine errors from our code (Godot's own leak
warnings at exit are ignored). A failure prints the checks that failed and the errors.

| Test | What it plays | About |
| --- | --- | --- |
| `stores` | The rules without the screen: bulk pricing, the prep list, ordering (minimums, delivery windows), fridge and dry-store vents, deliveries and rotation, mice, the inspector, traps | 5 s |
| `kitbox` | Equipment and the KitBox site: the starting kit, boards and knives for prep, cloths, checkout and the parcel, every phone page | 10 s |
| `wood_oven` | The wood oven's physics: the fire, the dome, the deck, pizzas baking faster by the fire and charring unless turned, feeding it, lighting it in the morning | 5 s |
| `traps` | Pest control on the floor plan: traps by the entry points catch more, droppings, laying a trap on the plan | 5 s |
| `boxes` | Folding pizza boxes by hand, in order | 5 s |
| `look_stick` | The look stick: turn, settle on a station, stay put elsewhere, tap to recentre | 25 s |
| `clock` | The clock above the hatch: its hands keep time; tapped like a finger, it clocks you in (opens), asks before clocking out early in service, and clocks you out at night (locks up); the on-screen time is only a readout | 20 s |
| `senior_training` | The senior's training day: every back-of-house job moves Marco's guide on, and it finishes | 1 min |
| `day` | A whole day in the van in 3D: the morning jobs, a full service shaped by touch, the phone, a complaint, the evening, dough, locking up, the next delivery | 1-2 min |
| `day_2d` | The same day in the classic 2D layout | 1-2 min |
| `day_wood` | The same day with a wood oven | 1-2 min |
| `first_week` | The story's first week with Marco: who does what each day, busier each day, the promotion | 10-12 min |

## Writing one

Make `tests/test_<name>.gd`:

```gdscript
extends "res://tests/bot.gd"
## What this plays, in a sentence or two.

func run() -> void:
	G.new_game()                      # the autoloads are G, S (Stock), D (Data), Dy (Day), H (Hygiene),
	await open_game()                 # M (Market), E (Equip), St (Story), T (Tutor); m is the main scene
	m.show_hub("home")
	await frames(10)
	check(G.s.day == 1, "a new game starts on day 1", G.s.day)
	await shot("home")                # tests/out/<name>/home.png
```

`check(ok, what, got)` records a check and prints `got` beside it, so a failure says what happened. Check what must
always hold (a pizza by the fire bakes faster than one by the mouth), not exact numbers that tuning will change. A
variant of another test can extend it and change a setting before calling `super()` (see `test_day_2d.gd`).
Add the name to `ORDER` in `run.sh` to place it in the run; tests not listed run last.
