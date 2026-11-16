# Crust Empire (Godot 4)

A hands-on pizza-making and restaurant-management game for phones, played in landscape.
You start alone in a pop-up pizza van and grow into a flagship trattoria.

Every system is in and playable. All artwork is placeholder shapes: see **Art** below.

## Run it

1. Install Godot 4.3 or newer (standard build, no C# needed).
2. Open `project.godot`.
3. Press Play. Mouse clicks stand in for touches on desktop.

The project is set to 1280x720, landscape, Compatibility renderer, so it exports to Android, iOS and web.

## How a day works

**Morning** - check stock in the Market, check the Today page, open for service.

**Service** has two places you switch between:
- **Front of house**: customers walk up to the hatch and queue (van, kiosk), or wait at the door, get seated,
  order at the table, eat and ask for the bill (shop and bigger). Tap whoever has a marker over them:
  ORDER, FOOD UP, SEAT, BILL, CLEAR.
- **Kitchen**: tap a ticket, shape the base, sauce it, cheese it, top it, bake it, slice it, send it to the pass.

**Evening** - make tomorrow's dough, place orders, lock up and sleep.

## Systems

- **Dough** (`scripts/dough_game.gd`): weigh flour, water, salt, yeast, oil and sugar on the scale. The batch is judged
  in baker's percentages. Too wet, too dry, too salty or no yeast = unusable. Then knead, then scale and ball.
  Four dough recipes: Neapolitan, New York, Roman thin, Deep pan.
- **Proofing**: dough made today is ready tomorrow and is binned after 3 days (overproofed). Too much yeast shortens
  its life, too little means it needs two nights.
- **Bases**: Neapolitan and New York are hand-stretched, Roman thin is rolled with a pin (or a dough sheeter upgrade),
  Deep pan is pressed into a pan. Each bakes for a different time.
- **Stock**: every ingredient is a dated lot with a shelf life and lives in the fridge, freezer or dry store.
  Stores have a capacity. Bigger premises allow bigger stores.
- **Menus**: a menu runs for 14 days. You book the next one in advance. Leftover stock the new menu does not use is waste.
- **Upgrades**: ovens, mixers, proofing, fridge, freezer, dry store, dough rolling, prep, dishwashing, suppliers,
  POS, signage, marketing, drinks, delivery, furniture, ambience, comfort, tables.
- **Staff**: pizzaioli, prep cook, oven tender, kitchen porter, head chef, counter assistant, servers, drivers, host,
  bartender, general manager. Each one takes over a real job in the service simulation.
- **Premises**: van, market kiosk, takeaway shop, pizzeria, high street restaurant, flagship.

## Code map

| File | What it does |
| --- | --- |
| `data/game_data.json` | All balance data: ingredients, dough recipes, pizzas, menus, venues, upgrades, roles |
| `scripts/data.gd` | Loads that JSON (autoload `Data`) |
| `scripts/game.gd` | Save file and rules: money, XP, stock, storage, dough ageing, menus, staff (autoload `Game`) |
| `scripts/art.gd` | Art and sound lookup by key (autoload `Art`) |
| `scripts/kit.gd` | Colours and styled UI controls |
| `scripts/main.gd` | Screen switching, modal, toast |
| `scripts/hub.gd` | Management screens |
| `scripts/dough_game.gd`, `scripts/meter.gd` | Dough making |
| `scripts/service.gd` | The service simulation and its UI |
| `scripts/front_scene.gd` | Draws the front of house and handles taps |
| `scripts/bench.gd` | Draws the pizza bench / cutting board and handles strokes |

## Art

No image files ship yet. Every picture is requested by key through `Art.tex(key)`; when
`res://assets/<key with dots as dashes>.png` exists it is drawn, otherwise a placeholder shape is drawn.
Adding art is dropping PNGs into `assets/` - no code changes. The full list of keys and sizes is in `ART_KEYS.md`.
UI colours and control styles all live in `scripts/kit.gd`.

## Web prototype

`web-prototype/` holds the earlier HTML/JS version (simpler dough, no front-of-house scene). It is kept for reference only.
