# Crust Empire: brief for the art and polish pass

## What this is

A pizza-making and restaurant-management game for phones in landscape, built in Godot 4.3 (GDScript,
Compatibility renderer). The player makes every pizza by hand, buys every ingredient by weight from real kinds
of suppliers, and grows a one-person pop-up van into a flagship trattoria with a full front- and back-of-house team.

All the game systems are built and playable. Everything you see is placeholder shapes and plain UI.
Your job is to make it look, feel and sound like a finished game without changing how it plays.

Read `README.md` for how a day works and a map of the code, and `ART_KEYS.md` for every image the game asks for.

## The owner's vision, in their words

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
- The story mode: start as an employed pizzaiolo making pizzas and prep to a checklist, then senior pizzaiolo running
  the back-of-house checks, ordering and checklists, then go solo in the van and work up to your own restaurant
  (see `ROADMAP.md`).

The owner supplied reference photos of the real kit: white 2 L and 4 L deli tubs, and a stainless pizza prep counter
with a granite/marble top, drawers and doors below, and a refrigerated rail of about ten gastronorm pans under a glass
sneeze guard. Ask the owner for the photos; the counter, tubs and rail should look like them.

## How the code is split (keep it this way)

- **Data** (`data/*.json`): every number and name. Add ingredients, suppliers, pizzas, menus, ovens here.
- **Rules** (autoloads `Data`, `Stock`, `Market`, `Game`, plus `pizza.gd`, `pizza_base.gd`, `oven.gd`,
  `service.gd`): no drawing at all.
- **Presentation** (`front_scene.gd`, `bench.gd`, `oven_view.gd`, `pizza_draw.gd`, `hub.gd`, the `*_page.gd`
  files, `kit.gd`): draws the state and turns touches into calls on the rules.

Art goes in through `Art.tex(key)`: drop a PNG at `assets/<key with dots as dashes>.png` and it replaces the
placeholder. Start there before touching drawing code. If you change a JSON shape, update `scripts/data.gd` too.
The save file is `user://crust_empire_v3.json`; changing what is saved means bumping that name.

## Work, in priority order

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

`scripts/pizza_draw.gd` draws a `Pizza` in layers: base, sauce (`sauce_amt`, a grid of how thick it was spread),
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

- A tutorial or first-day walkthrough. The game currently explains itself in text on each screen.
- A settings screen, save slots, cloud saves.
- Showing pizzas made by staff on the bench (they are simulated, not drawn).
- Delivery drivers on the road, and the van driving to the cash & carry.
- A freezer that needs defrosting, and frozen food that needs defrosting the day before.
- Weather and events. Seasons only change prices and what is available.

## Balance

Prices are close to real UK/US catering prices, so food cost runs at roughly 12-25% of the menu price, as it does in
a real pizzeria. The money in the game is in waste, portion control, grade choices and staffing. All of it is first-pass
tuning in the JSON files and is safe to adjust.
