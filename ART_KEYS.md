# Art keys

Every picture in the game is asked for by key through `Art.tex(key)` (`scripts/art.gd`).
Drop a PNG at `assets/<key with dots replaced by dashes>.png` and the game draws it instead of the
placeholder shape. No code changes. Example: key `bg.van` loads `assets/bg-van.png`.

Sizes are in game units: the front-of-house scene is 640 x 320, the bench and board are 320 x 320,
the oven is 400 x 320. Supply images at 3x those sizes or larger.

## 3D models for the first-person world (`scripts/fp/fp_world.gd`)

Every key below has a first-pass model, generated in Blender by the scripts in `tools/models/` (see
`tools/models/README.md`). They are `assets/models/fp-<key with dots as dashes>.gltf` + `.bin`, sharing the textures in
`assets/models/tex/`. To replace one, drop `assets/models/fp-<key>.glb` next to it: a `.glb` is loaded before the
`.gltf`, so yours wins with no code change. Delete the generated `.gltf` and `.bin` once you are happy with yours.

Follow the art style in `REPLIT_BRIEF.md` (chunky, rounded, warm colours, painted-in shadows). Shading baked into
vertex colours (`COLOR_0`) is multiplied into the material colour by the game, so bake ambient occlusion there
rather than into textures.

Metres, Y up, the player stands at the origin facing -Z with eyes at 1.62 m. Room and fixture models are placed at
the origin, so model them in room coordinates; small props are placed at their own position, so model them around
their own origin (base at y = 0). If no model exists for a key, the game builds a placeholder shape instead.

| Key | What it is |
| --- | --- |
| `fp.room.van`, `fp.room.kitchen` | The van interior (serving hatch in the front wall at z = -1.12, x -0.8..0.8, y 1.05..1.85, back door in the left wall at z 0.35..1.15) and the restaurant kitchen (open above the counters to the dining room). Walls at x ±1.64 and z 1.3, floor at y 0, ceiling at 2.25. Includes the extraction hood over the oven |
| `fp.street` | Outside the van and kiosk: pavement level with the customers' feet at y -0.42, the road beyond, shops across it at z -15.9 |
| `fp.dining` | The dining room beyond the pass (shop and up): x -5.2..4.2, z -14.1..-1.12, 3 m high. Keep the floor clear: the game puts tables at x -3.3..2.3, z -2..-13 |
| `fp.counter` | The pizza counter: stainless base, marble top at y 0.92 (x -0.81..0.81, z -1.12..-0.32), the chilled rail of pans along the back (z -1.13..-0.87), the sneeze guard and the ticket rail at y 1.96 |
| `fp.counter.side` | The counter on the right (x 0.81..1.63, z -1.12..-0.28) with the wooden board (board centre 1.16, 0.94, -0.72) and the ladle rail on the wall at y 1.3, z -1.075 |
| `fp.oven.electric`, `fp.oven.gas`, `fp.oven.wood`, `fp.oven.rotary` | The oven on the right, mouth facing the player at x 1.04, centred y 1.1, z 0.2, 0.78 x 0.62 (z -0.19..0.59, y 0.79..1.41). Nothing may stand in front of that rectangle: the oven view is drawn there in service. The body sits at x 1.0..1.62, z -0.27..0.83 |
| `fp.prep` | The prep station on the left: counter (x -1.63..-1.01, z -1.1..0.2), sink, tubs, shelf; the prep tablet's screen is at (-1.6, 1.42, -0.42), 0.86 x 0.63, facing +X |
| `fp.crates` | A delivery stacked by the back door, placed at (-1.2, 0, 0.75) |
| `fp.customer.0` .. `fp.customer.5` | A cartoon customer, about 1.76 m, facing +Z. Each leg hangs from a node named `hip_l` / `hip_r` (now at 0.79), with `knee_l` / `knee_r` below (at 0.44): the game turns those joints to sit the customer at a table, lowering them until the hips are at seat height (0.53 m) |
| `fp.rider` | A delivery-app rider with helmet and insulated bag, built like a customer |
| `fp.table` | A dining table (top surface at 0.765 m; plates go at x ±0.17) with four chairs 0.62 m out, facing it |
| `fp.pan` | One gastronorm pan, 0.1 m wide x 0.2 deep, rim at y +0.03. The game stretches its width to fit the slot; the fill is drawn by code |
| `fp.ladle.1` .. `fp.ladle.8` | Portion ladles by size in oz, hanging from the hook at the origin (placed on the ladle rail at y 1.3), bowl at the bottom facing +Z |
| `fp.ticket` | A paper order ticket, 0.19 x 0.26 m, centred on its origin and facing +Z; the text and the colour bars are drawn by code just in front of it |
| `fp.hand.right`, `fp.hand.left` | Forearm and hand, attached to the camera, pointing forward (-Z), fingertips at the origin |
| `fp.mouse` | A mouse running across the floor |
| `fp.pass` | The heated pass shelf behind the cutting board where finished pizzas go out (tap target), at (1.5, 0.92, -1.02) |
| `fp.bin` | The scraps bin at the left end of the counter, at (-0.62, 0.92, -0.78) |
| `fp.sheeter` | A tabletop dough sheeter (only with the sheeter upgrade), at (-0.62, 0.92, -0.45) |
| `fp.logs` | Logs in a rack beside a wood oven's mouth, at (1.12, 0.6, 0.72) |
| `fp.fridge` | Upright fridge against the back wall, door facing -Z, door front at local z -0.35 (placed at -0.62, 0, 0.97) |
| `fp.thermometer` | The fridge thermometer on the door, face toward -Z (placed at -0.45, 1.45, 0.62) |
| `fp.freezer` | Chest freezer (only when the premises has one), at (1.3, 0, 1.08) |
| `fp.drystore` | Dry store shelving with flour sacks, tins and jars (placed at 0.42, 0, 1.08) |
| `fp.mop`, `fp.spray`, `fp.trapbox` | Mop and bucket, spray bottle, box of traps |
| `fp.boxes` | A wall shelf of pizza boxes, at (1.32, 1.8, -1.0). The two stacks are nodes named `flat` and `folded`, each with its origin at its base: the game scales them up and down with stock |
| `fp.mixer`, `fp.bowl` | The dough mixer (any mixer upgrade) or the mixing bowl, on the prep counter at (-1.38, 0.92, -1.0), front toward +X |
| `fp.dough_trays` | Lidded dough proving trays, stacked, at (1.47, 0.92, -0.38) |
| `fp.clipboard`, `fp.sign` | The checklist clipboard and the OPEN / LOCK UP sign at the hatch (the text is drawn by code 4 cm in front of the sign) |

## Front of house, classic 2D layout (`scripts/front_scene.gd`)

| Key | Size | What it is |
| --- | --- | --- |
| `bg.van` | 640x320 | Street scene, van on the left with its hatch facing right at about (232,170). Customers queue to the right along y=228 and wait for food along y=292 |
| `bg.kiosk` | 640x320 | Covered market, kiosk on the left, same layout as the van |
| `bg.shop` | 640x320 | Room from above: the pass along the left wall (x < 54), door bottom right, tables placed by code in x 195-625, y 22-257 |
| `bg.pizzeria`, `bg.restaurant`, `bg.flagship` | 640x320 | Same layout as the shop, bigger and smarter rooms |
| `customer.0` .. `customer.5` | 30x52 | A standing customer, front view, six looks |
| `seated.0` .. `seated.5` | 18x18 | A seated guest seen from above, six looks |
| `table.clean`, `table.food`, `table.dirty` | 44x34 | A table from above: laid, with pizzas on it, with dirty plates |
| `bubble.order`, `bubble.food`, `bubble.seat`, `bubble.bill`, `bubble.clear`, `bubble.delivery` | 30x30 | The marker over anyone (or any table, or the back door) that needs you |
| `bubble.complaint` | 30x30 | A customer complaining |
| `bubble.rider` | 30x30 | A delivery-app rider waiting for an order |
| `rider` | 34x52 | A delivery-app rider in a helmet with an insulated bag on their back, front view (the app is fictional: Hungrr, teal) |
| `crates` | 36x28 | A delivery stacked at the back door (bottom left of the van scene, by the pass in dining rooms) |
| `mouse` | 22x12 | A mouse running across the floor, facing right |

## Kitchen bench and cutting board (`scripts/bench.gd`, `scripts/pizza_draw.gd`)

| Key | Size | What it is |
| --- | --- | --- |
| `bench.bg` | 320x320 | The marble top of the pizza counter, floured, top-down |
| `board.bg` | 320x320 | Wooden cutting board, top-down |
| `pan` | 220x220 | Round deep pizza pan, top-down (deep-pan and gluten-free bases) |
| `pin` | 150x26 | Rolling pin, top-down, horizontal |
| `top.<id>` | 24x24 | One piece of a topping, top-down. Ids: parmesan, gorgonzola, ricotta, pecorino, goatcheese, burrata, taleggio, pepperoni, ham, prosciutto, salami, spicysalami, sausage, nduja, pancetta, guanciale, chicken, meatball, speck, mortadella, anchovy, tuna, prawn, seafood, salmon, mushroom, porcini, pepper, onion, olive, artichoke, rocket, spinach, cherrytom, sundried, aubergine, courgette, sweetcorn, pineapple, chilli, jalapeno, garlic, potato, friarielli, caper, truffle, basil, oregano, rosemary, honey, pistachio, chocspread (a dollop of chocolate hazelnut spread) |
| `dough.blob` | 180x180 | A ball of dough, for the kneading step |
| `rail` | full width x 78 | The chilled rail of the pizza counter under its glass sneeze guard, seen from the front |
| `pan` | about 90x60 | One stainless gastronorm pan, empty |
| `fill.<id>` | about 90x40 | The food in a pan (grated mozzarella, sliced mushrooms, sauce...), drawn to how full it is |
| `clean.boh`, `clean.foh` | 640x280 | The surface being scrubbed: stainless and marble in the kitchen, the counter or tables in front |

The base, sauce, cheese, browning and cuts are drawn by code because they change shape as you work.
See `PizzaDraw.draw()`; each layer is a separate block and can be swapped for shaders or textures one at a time.

## Pest control and boxes (`scripts/trap_task.gd`, `scripts/fold_task.gd`)

| Key | Size | What it is |
| --- | --- | --- |
| `plan.0` .. `plan.5` | 640x320 | Floor plan of each premises from above (van, kiosk, shop, pizzeria, restaurant, flagship). Rooms, walls, doors, drains, pipe holes and air bricks must sit where `data/floorplans.json` puts them |
| `trap`, `trap.sprung` | 24x14 | A snap trap or bait station from above, set and sprung |
| `droppings` | 8x8 | Mouse droppings |
| `box.flat` | 320x320 | A flat pizza box blank from above, with its front, sides and lid flaps |
| `box.folded` | 110x9 | A closed pizza box seen from the side, for the stack by the pass |

## Oven (`scripts/oven_view.gd`)

| Key | Size | What it is |
| --- | --- | --- |
| `oven.electric`, `oven.gas`, `oven.wood`, `oven.rotary` | 400x320 | Looking into the oven from the front: the deck, with the landing shelf along the bottom (y > 256). Wood and rotary ovens have the fire on the left at about (58,129) |
| `oven.fire` | 80x120 | The flame. It is scaled by how hot the fire is |

Pizza spots on the deck are laid out by code (`Oven._init`).

## KitBox, the equipment website (`scripts/shop_page.gd`)

| Key | Size | What it is |
| --- | --- | --- |
| `kit.logo` | 150x44 | The KitBox logo for the site header (a fictional catering-supplies site, so make it our own brand) |
| `kit.<id>` | 84x84 | Product photo on a white or pale background, like a catering catalogue. All 53 ids are in `data/equipment.json`: ladle_1, ladle_2, ladle_3, ladle_4, ladle_6, ladle_8, peel, turner, wheel, rocker, scraper, pin, docker, pan_tin, dough_tray, oven_brush, ir_thermo, serving_board, knife, board_green, board_red, board_yellow, board_blue, board_white, board_brown, board_purple, knife_purple, grater, rotary, blender, colander, fry_pan, saucepan, bowl, jug, scales, probe, gn16, gn13, fridge_thermo, daydots, mop_boh, mop_foh, spray, cloths, plate, cutlery, glass, delivery_bag, first_aid, fire_blanket, extinguisher, handwash |

## Icons (`scripts/kit.gd`)

| Key | Size | What it is |
| --- | --- | --- |
| `icon.<id>` | 22x22 | Ingredient icon in the supplier catalogue and stock lists. All 89 ids are in `data/ingredients.json`, including the drinks (cola, lemonade, water, coffee, milk, beer, redwine, whitewine, prosecco, aperitivo, gin, vermouth) and desserts (chocspread, tiramisu, gelato) |

## Sound (`scripts/art.gd`)

`assets/sfx/ding.wav` (new order), `cash.wav` (paid), `bad.wav` (customer left), `tap.wav`, `up.wav` (level up, dough done).
