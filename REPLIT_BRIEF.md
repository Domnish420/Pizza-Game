# Crust Empire: brief for the art and polish pass

## What this is

A pizza-making and restaurant-management game for phones in landscape, built in Godot 4.3 (GDScript,
Compatibility renderer). The player makes every pizza by hand, buys every ingredient by weight from real kinds
of suppliers, and grows a one-person pop-up van into a flagship trattoria with a full front- and back-of-house team.

**The art direction is 3D and first person.** Service is played from a chest-mounted GoPro-style camera: you are
standing at your station in the van or the kitchen, your forearms and hands at the bottom of the frame, and everything
you work with is a 3D object in the room that you touch where it is. Think a VR game played on a phone. The 3D world
is built and playable with placeholder shapes (`scripts/fp/`); every prop is swappable for a model by key.

All the game systems are built and playable. Everything you see is placeholder shapes and plain UI.
Your job is to make it look, feel and sound like a finished game without changing how it plays.

Read `README.md` for how a day works and a map of the code, and `ART_KEYS.md` for every image the game asks for.

## The owner's vision, in their words

- "My vision for the art of the game is 3D, all of it to be 3D interactable. I want the game really to be from a
  GoPro angle, having it all be first person. Like a VR game for mobile."

- "I want to be making all of it (dough, the pizza itself, etc), buying ingredients and managing a restaurant."
- "Everything is real upgrades you would do to your back and front of house."
- "A fully interactive scene where I take orders from customers in each setting (customers walk up to the van,
  have to take orders from people sitting down etc.)"
- "Two fingers to stretch dough ... the dough forms properly from all the different techniques and methods of
  dough stretching for the crust you want or the thinness of the base."
- "Put the pizza in the oven myself and be the one turning it. Starting with an electric oven: put it in and leave it,
  2 at a time, in a pop-up van. Later a wood-fire that we need to turn to make sure it's all cooking and colouring properly."
- "Buying things by weight, as you would in real life", from "different businesses for different quality
  ingredients that all have variable costs". Quality costs more but customers tip more; quantity over quality is a
  valid choice when money is short.
- "Keep to a stock list so you're not over-using and losing money on the pizzas."
- "Customers rate the look of your pizza, giving tips and ratings depending on everything that made service."
- "Buying in larger amounts is always cheaper no matter the product. Some products you can only buy in bulk, like
  flour: only large 25 kg bags."
- "Watch out for stock rotation and spoilage, making sure ventilation is occurring in areas that need it. Not enough in
  fridges causes spoilage earlier and too much makes the fridges freeze. Not enough in the dry store causes spoilage
  and too much allows bugs and pests in (and rodents getting in if the kitchen and front of house aren't cleaned
  properly and traps aren't laid)."
- "Stock is always bought the day before, but suppliers deliver at varying times depending on the season and day of
  the week. Some only deliver on certain days, some are next-day. It's all about rotating stock correctly and not
  over-supplying."
- "Prep is done in the morning. If you run out of prep mid-shift, you have to prep it, or take it off the menu if
  there isn't time or you don't have the staff to prep while you're serving."
- "I want a fully immersive experience."
- "Prep is done into tubs (2 L and 4 L), and these are put into gastros on top of the fridge. The pizza counter has a
  marble base, which is the top we need for stretching dough, and the glass counter is where we put our toppings."
- "Sauce is taken out with a ladle of a specific amount, 1 oz, 2 oz, 4 oz. 2 oz is the amount you need: take the sauce
  out, drop it onto the pizza, then spread it out. That way you only use the amount needed." Every ladle size is bought
  separately, and you need several because more than one section uses them.
- "Make all kitchen utensils like this, we will have a multitude of them", bought from "our own" catering-supplies
  site (modelled on the big UK catering suppliers). In the game it is KitBox; rename it in `data/equipment.json`.
- The story mode: start as an employed pizzaiolo making pizzas and prep to a checklist, then senior pizzaiolo running
  the back-of-house checks, ordering and checklists, then go solo in the van and work up to your own restaurant
  (see `ROADMAP.md`).

The owner supplied reference photos of the real kit: white 2 L and 4 L deli tubs, and a stainless pizza prep counter
with a granite/marble top, drawers and doors below, and a refrigerated rail of about ten gastronorm pans under a glass
sneeze guard. Ask the owner for the photos; the counter, tubs and rail should look like them.

## The art style (decided with the owner)

Chunky, bright and toy-like, in the spirit of *Job Simulator* and *Overcooked*: a first-person game you play with
your hands, where everything looks good to pick up. The owner tried the idea of a PS2-era look and chose this
instead; the PS2 look lives on as an optional "Retro look" switch on the phone's Today page.

- **Shapes**: chunky and rounded. Every box has soft rounded edges, handles and knobs are oversized and easy to
  read as "grab me", props are slightly larger than life. No fine fiddly detail.
- **Colour**: warm and saturated, from the ingredients: tomato `#e0533a`, basil `#4caf50`, mozzarella/cheese
  `#f4c64f`, cream `#f6efe0`, crust `#e3a35c`, terracotta `#c8643a`, wood `#c98b52`, teal `#2fb39a` as the accent
  for handles and the bin, charcoal `#33383b` instead of black. Steel is light and painted-looking, not a dark
  mirror. The palette is in `tools/models/common.py`.
- **Light**: warm and soft. Shadows are painted in: ambient occlusion is baked into every model's vertex colours
  (corners, creases, contact with the floor), in a warm tint rather than black, and the game multiplies them into the
  colours. Rooms are baked with their fixtures standing in them, so the floor darkens round the counters.
- **Textures**: few and soft. Flat colour by default; small (128-256 px) painted-looking textures only where they add
  something (marble, wood, tiles, the oven's mosaic). No bump or normal maps.
- **People**: friendly cartoon proportions: big round heads with simple faces (big eyes, eyebrows, a smile), short
  chunky bodies, mitten hands, big shoes, lots of colour. Never realistic faces.
- **The pizza is the hero**: the one thing allowed real detail and appetite appeal (stretchy dough, glossy sauce,
  melting cheese, leopard-spot char, steam), standing out against the simple world.
- **Text stays sharp**: labels, tickets and the HUD are always drawn at full resolution.
- **Phone budget**: about 4,000 triangles for a person, a few hundred to 5,000 for a prop, up to about 15,000 for a
  room; a whole scene is about 100,000.

## How the code is split (keep it this way)

- **Data** (`data/*.json`): every number and name. Add ingredients, suppliers, pizzas, menus, ovens here.
- **The 3D world** (`scripts/fp/`): presentation only. It reads the service state and calls the same methods the 2D
  layout does (`rail_tap`, `claim`, `do_action`, `set_view`); it never changes the rules.
- **Rules** (autoloads `Data`, `Stock`, `Market`, `Game`, plus `pizza.gd`, `pizza_base.gd`, `oven.gd`,
  `service.gd`): no drawing at all.
- **Presentation** (`front_scene.gd`, `bench.gd`, `oven_view.gd`, `pizza_draw.gd`, `hub.gd`, the `*_page.gd`
  files, `kit.gd`): draws the state and turns touches into calls on the rules.

Art goes in through `Art.tex(key)`: drop a PNG at `assets/<key with dots as dashes>.png` and it replaces the
placeholder. Start there before touching drawing code. If you change a JSON shape, update `scripts/data.gd` too.
The save file is `user://crust_empire_v8.json`; changing what is saved means bumping that name.

## Work, in priority order

### 0. The 3D first-person world (do this first: everything else lives in it)

Service runs in `scripts/fp/`. `FPWorld` builds the room, `FPView` puts it on screen behind a light HUD, and
`FPSurface` turns a 2D station control into a working surface in the room.

- **The camera** (`FPWorld._camera`, `STATION_LEAN`, `STATION_AT`, `STATION_FOV`): eye height 1.62 m, standing at the
  origin facing -Z. Five stations: front (the hatch or the pass), bench, board, oven and prep. Station buttons turn your
  head and lean you in. You can also drag on anything that isn't a surface to look around (let go near a station and you
  settle on it), or turn the phone, which uses the gyroscope. Keep the wide, slightly low chest-cam framing: the hands
  should be in shot.
- **The hands** (`hand.right`, `hand.left`): the right hand follows your first finger on a surface and the left your
  second (two-finger stretching uses both). Replace them with rigged forearms: pressing, stretching, holding the ladle,
  the peel, the wheel. Drive the pose from which tool is in use (`svc.tool`, `svc.view`).
- **The surfaces**: the marble bench, the cutting board, the oven mouth and the prep tablet each show the game's 2D
  control (Bench, OvenView, the prep list) rendered onto a flat quad, with touches projected through. Every mechanic
  already works in 3D this way.
  - **The pizza is now 3D on the bench and the board** (`scripts/fp/pizza_3d.gd`, `shaders/pizza.gdshader`). It is
    rebuilt live from the pizza's data whenever it changes: the dough is a mesh round `PizzaBase` (a dome as a ball,
    then a flat middle and a puffy cornicione wherever the rim is still unpressed); sauce and cheese come from a
    one-pixel-per-cell map of `sauce_amt` / `cheese_amt` and are drawn per pixel (glossy sauce, raw shreds, melted
    pools with golden blisters); toppings are instanced meshes per shape from `Pizza.tops`; the crust browns sector
    by sector from `Pizza.bake` with leopard spots when pushed; cuts are grooves; it steams on the board; a pan pizza
    sits in its pan. The bench and board quads are now see-through overlays drawn on top (`FPSurface.overlay()`,
    `Bench.draw3d`), so the size guides and your fingertips still show and touches map exactly as before.
  - Next: the oven. `OvenView` still draws the deck as a flat top-down map on the oven mouth. Making it 3D means a
    hollow oven with a visible deck, a horizontal touch surface inside it, and `Pizza3D` per deck spot.
  - Keep the touch mapping: either keep the quad as an invisible hit plane (`FPSurface.to_px`), or raycast onto the new
    mesh and convert to the same bench coordinates.
- **No step buttons.** The owner wants the pizza free: "Don't need the base is ready button, get rid of the buttons.
  The dough is ready to go in the oven the moment the dough touches the table. Ingredients can be put on whenever,
  wherever." So the pizza has no stages. Empty hand shapes, two fingers always stretch, a held topping goes on where
  your finger goes, turning to the oven carries the pizza on the peel, and the pass, bin, sheeter and log stack are
  objects in the room. Keep it that way: no buttons for steps.
- **Tappable 3D objects**: the pass, the bin, the dough sheeter and the logs beside a wood oven; the gastro pans on the rail (fill level, the topping in your hand highlighted), the portion
  ladles on their rack, the paper tickets on the ticket rail (with a patience strip), customers with their markers,
  tables, delivery-app riders and the delivery crates by the back door. Each is a StaticBody3D with an `act` meta;
  keep that when you swap in a model.
- **Models**: every prop calls `Art.model("fp.<key>")` and falls back to a placeholder. All 50 keys now have a
  model in the art style above, generated in Blender by the scripts in `tools/models/` (`tools/models/README.md`): the van
  interior with its propped-up hatch, the street of shops outside, the restaurant kitchen (tiled) and dining room
  (beams, lamps, pictures, windows, plants), the counter with its marble top and chilled rail, the side counter and
  ladle rail, all four ovens (electric and gas decks, a mosaic wood dome, a rotary), the prep station, fridge,
  freezer, dry store, mop, boxes, mixer, trays, crates, pans, eight colour-coded ladles, tickets, tables with
  chairs, six customers, the rider, the hands and a mouse. They are deliberately simple and clean. Improve on them
  freely: drop `assets/models/fp-<key>.glb` and it replaces the generated `.gltf` with no code change, or edit the
  scripts and rebuild. The keys, sizes and positions are in `ART_KEYS.md`.
- **Customers** are placed from the simulation's 2D positions (`FPWorld._to3d`) and face the hatch or pass with their
  front (+Z). They sit at tables by bending the `hip_*` and `knee_*` joints in the model. They still need walk, idle,
  order (talking), waiting-impatiently, eating and leaving animations.
- **Between services** (`scripts/fp/kitchen_screen.gd`): the morning and evening happen in the same 3D kitchen with
  no service running. Every job is a prop with a live label: the delivery crates, prep tubs, sink with dirty tubs,
  pans on the rail, mixer or bowl, proving trays, mop and bucket, spray, box of traps, pizza boxes on the shelf, the
  fridge with its thermometer, the freezer, the dry store shelves, the checklist clipboard and the OPEN / LOCK UP sign.
  Tapping one runs the job (`KitchenScreen.job`).
- **The phone**: the management screens (`Hub`) open in a phone overlay. A modelled phone held in the left hand,
  raised into view, would be the natural upgrade.
- **Still flat** (next to bring into 3D): the hands-on minigames open as 2D sheets over the world: prep (knife,
  grater, picking, pouring, stirring), cleaning, unpacking deliveries onto shelves, traps on the floor plan, folding
  boxes, and making dough. They work and are scored; each would be better done on the 3D prop it starts from (the knife
  through the mushroom on the prep board, the mop on the real floor, crates unpacked onto the real shelves, traps placed
  on the real floor, the dough in the real mixer).
- The classic 2D layout is still there (on the phone's Today page, "Service in 3D: off") for testing; keep it working.
- Performance: the Compatibility renderer, four small SubViewports for the surfaces, unshaded quads. Keep the polygon
  budget phone-sized, bake lighting where you can, and check frame time on a low-end Android phone.

### 1. Dough forming (the centrepiece)

`scripts/pizza_base.gd` is the dough. It is an outline of 24 sectors around the centre. Each sector has a radius
(`r`) and a rim width (`rim`: the puffy edge that has not been pressed yet). The ball has a fixed weight, so
opening it wider makes it thinner (`thickness_mm()`). Each dough recipe in `data/doughs.json` sets the target
diameter (`size_cm`), rim (`crust_cm`) and method (`hand`, `roll`, `press`). `score()` judges size and rim.

Techniques are methods on `PizzaBase`, called from `scripts/bench.gd` (touch input):

| Method | Gesture now |
| --- | --- |
| `press(p)` | one finger: fingertip press, pushes gas to the rim |
| `stretch(p0, p1)` | two fingers spreading apart (each finger calls it) |
| `rotate(by)` | two fingers twisting |
| `roll(p, mv)` | rolling pin, one or two fingers |
| `pan(p, mv)` | pushing into a pan |
| `sheet(evenness)` | the dough sheeter button |

To add a technique (slap, knuckle stretch, toss, docking with a roller, edge pinching), add a method that edits
`r`, `rim` and `rot`, and a gesture in `bench.gd` that calls it. If you need thickness to vary across the base,
add a per-sector or per-cell thickness array here, and have `score()` and `PizzaDraw` read it. Then make the
dough look like dough: a deforming mesh or shader that shows thickness, the puffed rim and flour, driven by those arrays.

### 2. The pizza and the bake

In the 3D kitchen the pizza on the bench and the board is `Pizza3D` (see section 0); in the oven and the classic
2D layout, `scripts/pizza_draw.gd` draws a `Pizza` in layers: base, sauce (`sauce_amt`, a grid of how thick it was spread),
cheese (`cheese_amt`), toppings (`tops`, each with position and angle), browning, cuts. Browning comes from
`Pizza.bake`: 12 values round the edge, 1.0 = done, 1.4 = burnt, plus `floor` for the underside.
The wood oven makes the side facing the fire brown first, so those 12 values differ. Show it: leopard spotting,
blistered rim, melted and browned cheese, charring on the side that faced the flame. Keep the layer order.

### 3. The oven

`scripts/oven_view.gd` shows the deck and handles dragging pizzas in, spinning them by the edge and dragging them out.
`scripts/oven.gd` has the heat model (types and numbers are in `data/upgrades.json` under `ovens`).
Wanted: an oven front for each type, the fire (feeding a log could be dragging a log in), a peel to load and turn
pizzas, heat shimmer, and a clear "done" moment.

### 4. Front of house

`scripts/front_scene.gd` draws the customers, queue, tables and markers. The simulation in `service.gd` already moves
every customer (`parties[].pos` and `.target`), seats them, and tracks waiting, eating and paying. Wanted: a scene per
venue (van on a street, kiosk in a market, then dining rooms), walking, sitting and eating animations, speech
bubbles, the hatch, and the pizza being handed over. Layout rules for the backgrounds are in `ART_KEYS.md`.

### 4a. Story mode

`scripts/story.gd` runs the career: pizzaiolo at Bella Napoli (fictional), senior pizzaiolo, then your own van.
The boss is Marco and the crew are Luca, Sofia, Tom, Aisha and Kofi (all fictional). Right now they speak through
text in dialogs and on the Today page. They need faces, a few lines of personality, and small scenes for the
moments that matter: the first morning, each shift review, the promotion, and handing in your notice.

**Training days** (`scripts/tutor.gd`). Before the first shift and before the first senior shift, Marco walks the
player through the day in the 3D kitchen. Right now he is a text box at the bottom of the screen with his name, a
"Skip training" button, and a yellow cone and ring (`FPWorld.set_highlight`) floating over the thing to touch. A HUD
button can be lit with a yellow border instead. Ideas for the art pass, keeping the same steps and checks:
- Marco as a person standing in the kitchen who points, or his hands demonstrating (pressing the dough, the ladle
  spiral), with his lines voiced or as speech bubbles.
- A nicer marker: a glow on the object itself, or a hand icon tapping it.
- A small celebration when a step is done (the step already plays the `up` sound).
Each step's text is in `_pizzaiolo()` and `_senior()`; its check is a plain function on the game state, so the
wording and the look can change freely without touching the checks.

### 4b. The counter and the hands-on jobs

The bench is the marble top of the pizza counter, with the rail of gastro pans above it (`scripts/rail_view.gd`).
Prep (`prep_task.gd`: knife, grater, picking, pouring, stirring), cleaning (`clean_task.gd`) and unpacking deliveries
(`shelf_task.gd`) are hands-on minigames with placeholder drawing. They need real art and animation: the knife
through a mushroom, cheese shredding off the grater, a tub filling, a day-dot sticker going on the lid.

### 5. The back of house between services

The morning and evening are a list of jobs on the clock (`scripts/jobs_page.gd`, rules in `scripts/day.gd`):
deliveries at the back door, the prep list, cleaning, traps, rotating the stores, and the vents on the Stores page.
They work as buttons now. They would be far more immersive as scenes: a walk-in fridge and dry store you can see
filling up (with frost when the vents are too open and condensation when too closed), crates to unpack onto shelves
(new stock behind old), a prep bench with knife work for slicing and grating, mops and spray, traps to set by hand.
The data each scene needs is already there: lots per shelf with dates and the in-front flag, fill level, temperature
and humidity, cleanliness per area, pest level, traps down and sprung.

### 5a. KitBox, the equipment website

`scripts/shop_page.gd` is a catering-supplies website inside the game: header with the basket and checkout, a category
bar, product cards, "What you need" and "Your orders". It should feel like browsing a real supplier's site on a phone:
product photos (`kit.<id>`), a logo, a basket badge, a delivery banner. The utensils also deserve to be seen in use:
the peel sliding under a pizza, the wheel or rocker slicing, the ladle pooling and spreading sauce, the colour-coded
boards at the prep station, day-dots on the tubs. What each item does in the rules is in `scripts/equip.gd`.

### 5b. Traps, boxes, extras and the delivery app

- Pest control is laid out on a floor plan of each premises (`scripts/trap_task.gd`, `data/floorplans.json`). It needs
  real plans (`plan.<n>`), traps and droppings. Keep the doors, drains, pipe holes and air bricks where the data puts them.
- Folding a pizza box (`scripts/fold_task.gd`) is four drags; it wants a box blank that folds up in four stages.
- Sides, desserts and drinks (`data/extras.json`) appear on tickets and the Menu page. Garlic bread and the chocolate
  pizzetta use the pizza drawing; salad, tiramisu, ice cream and drinks would benefit from small plated/served images.
- The delivery app is a fictional brand (Hungrr, teal). Its tablet is a pulsing button in the service top bar and its
  riders wait out front. A proper tablet pop-up with a ping, and a rider on a scooter, would sell it.

### 6. Screens and UI

All colours, buttons, panels and labels come from `scripts/kit.gd`. Turning that into a Godot `Theme` restyles
every screen at once. The supplier catalogue, stores and recipe cards are data-heavy; keep them readable on a phone.

### 7. Sound and feel

`Art.sfx(name)` plays `assets/sfx/<name>.wav` if it exists (ding, cash, bad, tap, up). Add more where it helps:
dough slaps, the sauce ladle, the oven door, the fire, the pizza wheel, a busy dining room.

## Test on a real phone

- Two-finger stretching has only been tested with simulated touch events. Check it on Android and iOS devices.
- Check that drawing a pizza (many small circles) stays smooth on a low-end phone, especially at the flagship with
  many pizzas in the oven. If it does not, bake layers to textures.
- Orientation is set to sensor landscape.

## Not built yet (fair game)

- A tutorial for free play (story mode has the training days; free play explains itself in text on each screen).
- A settings screen, save slots, cloud saves.
- Showing pizzas made by staff on the bench (they are simulated, not drawn).
- Delivery drivers on the road, and the van driving to the cash & carry.
- A freezer that needs defrosting, and frozen food that needs defrosting the day before.
- Weather and events. Seasons only change prices and what is available.

## Balance

Prices are close to real UK/US catering prices, so food cost runs at roughly 12-25% of the menu price, as it does in
a real pizzeria. The money in the game is in waste, portion control, grade choices and staffing. All of it is first-pass
tuning in the JSON files and is safe to adjust.
