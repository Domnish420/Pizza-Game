# Tests

Bots that play the real game and check it behaves. Each one loads the game's autoloads (and the main scene, when it
needs the screen), plays by calling the same methods a touch would, and checks what must hold. They need Godot 4.7
and a display; `run.sh` gives them a virtual one with `xvfb-run`.

```
tests/run.sh                      # all of them, quickest first
tests/run.sh day look_stick       # just these (the name is the part after test_)
GODOT=~/Godot_v4.7.2 tests/run.sh   # a Godot binary that is not on the PATH
```

Each bot's log and screenshots go to `tests/out/<name>/` (not committed). A bot passes when it exits 0, its last line
is `PASS: n checks, 0 failed`, and the log has no script errors or engine errors from our code (Godot's own leak
warnings at exit are ignored). A failure prints the checks that failed and the errors.

| Test | What it plays | About |
| --- | --- | --- |
| `stores` | The rules without the screen: bulk pricing, the prep list, ordering (minimums, delivery windows), fridge and dry-store vents, deliveries and rotation, mice, the inspector, traps | 5 s |
| `kitbox` | Equipment and the KitBox site: the starting kit, boards and knives for prep, cloths, checkout and the parcel, every phone page | 10 s |
| `wood_oven` | The wood oven's physics: the fire, the dome, the deck, pizzas baking faster by the fire and charring unless turned, leopard spots on one side unturned and all round turned (few by the mouth), feeding it, lighting it in the morning | 5 s |
| `peel` | The turning peel in a wood oven in 3D: touching the edge lifts that side (it tilts up in 3D), pushing turns it right and pulling left (the other way lifted on the right), lifted it browns less underneath, turned every second it leopard-spots all round and the review says so | 15 s |
| `dough` | Opening a base by hand in 3D with real touches: a fingertip presses it, a flick outward from the crust slaps it (the crust kept), two fingers held still lift it onto your knuckles (it rises in 3D), turning them stretches it evenly, turning and flicking off tosses it spinning (up in 3D with its shadow, down bigger and rounder, caught by a finger; caught on two it is back on your knuckles and thrown again), no turn flops, gently let go sets it down, a thin base spun too fast tears (a hole, and the review says so); thickness: pressed out evenly it is even, a fingertip working the middle leaves it thin there and thick round it (the review says so), on your knuckles it evens out, keep on at one spot and it goes through | 2 min |
| `traps` | Pest control on the floor plan: traps by the entry points catch more, droppings, laying a trap on the plan | 5 s |
| `boxes` | Folding pizza boxes by hand, in order | 5 s |
| `look_stick` | The look stick: turn, settle on a station, stay put elsewhere, tap to recentre | 25 s |
| `phone_look` | Looking with the phone (a fake gyroscope): turning to a station puts you there without snapping, a glance does not count, the view holds still while a thumb works, the station buttons face you to a station; each thumb a hand: the left thumb presses the dough while the right scatters the cheese, the held topping shows in its hand, the put-down button under that thumb, the thumb that taps a pan holds it | 25 s |
| `pad` | A game controller (a stand-in): the sticks move the hands, a trigger on a pan picks it up with that hand, the left hand presses the dough while the right spreads the cheese, a stick click lets go, both triggers held still lift the dough, steering the sticks turns it, letting go with the sticks pushed tosses it, the stick snapped outward from the crust slaps it, the shoulders turn to the next station; on the 2D screens: the Phone button in the top bar, putting the phone away, scrubbing a cleaning sheet; a dialog focuses its main button; a touch puts the hands away; the title's menu with the rings | 40 s |
| `vr` | Phone VR with a stand-in headset: two eyes an eye's width apart into the kitchen, the screens on a panel, the head turning (and tilting) the view at once, turning to a station, the game moving you on not turning you, the shoulders and Start, into service, the viewer's button as your right hand, a dialog where you look, leaving VR, the title on the panel in a quiet room, looking at New game and clicking it with the viewer's button | 25 s |
| `ar` | AR with a stand-in phone: walking and crouching move you, turning to a station, Start puts you back, the camera mode (camera picture behind, walls gone), AR in a VR viewer, AR off | 30 s |
| `quest` | The Quest with a stand-in headset: VR from the start, the headset's camera is the game's head, walking, the thumbstick turns, a fingertip presses the dough and lifts off, a pinch at the cheese pan, both fingertips at once (cheese and dough), B puts down, standing the bench at its real height for a tall player and seated at a desk's height, both fingertips held still lift the dough (up where your hands hold it), turning your hands stretches it and throwing it up tosses it, hands under it catch it, lowered to the marble it is set down, a pinch on the panel's Oven button, buzzing, passthrough for the kitchen in your room, the title by pointing | 25 s |
| `controls` | Look speed and invert, the stick on the right with bigger buttons, the put-down button (on screen), cut assist, a burning pizza pulsing the Oven button, the performance overlay, Graphics: Low | 40 s |
| `clock` | The clock above the hatch: its hands keep time; tapped like a finger, it clocks you in (opens), asks before clocking out early in service, and clocks you out at night (locks up); the on-screen time is only a readout | 20 s |
| `sound` | Every sound the code asks for exists and loads; the fire crackles by a lit wood oven and the room hums, both fade when you leave the kitchen; the music plays on the title and between services, not in service; mute silences everything; vibration follows its setting; a pizza starting to burn is announced once | 20 s |
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

`await until(func(): return x, seconds)` waits for something that follows a short delay in the game (a station
picked after you look at it for a moment) without guessing how long a frame takes on a slow machine.
`check(ok, what, got)` records a check and prints `got` beside it, so a failure says what happened. Check what must
always hold (a pizza by the fire bakes faster than one by the mouth), not exact numbers that tuning will change. A
variant of another test can extend it and change a setting before calling `super()` (see `test_day_2d.gd`).
Add the name to `ORDER` in `run.sh` to place it in the run; tests not listed run last.
