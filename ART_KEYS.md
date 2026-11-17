# Art keys

Every picture in the game is asked for by key through `Art.tex(key)` (`scripts/art.gd`).
Drop a PNG at `assets/<key with dots replaced by dashes>.png` and the game draws it instead of the
placeholder shape. No code changes. Example: key `bg.van` loads `assets/bg-van.png`.

Sizes are in game units: the front-of-house scene is 640 x 320, the bench and board are 320 x 320,
the oven is 400 x 320. Supply images at 3x those sizes or larger.

## 3D models for the first-person world (`scripts/fp/fp_world.gd`)

Drop `assets/models/fp-<key with dots as dashes>.glb` (or .gltf / .tscn). Metres, Y up, the player stands at the
origin facing -Z with eyes at 1.62 m. Room and fixture models are placed at the origin, so model them in room
coordinates; small props are placed at their own position, so model them around their own origin (base at y = 0).

| Key | What it is |
| --- | --- |
| `fp.room.van`, `fp.room.kitchen` | The van interior (serving hatch in the front wall at z = -1.12, x -0.8..0.8, y 1.05..1.85, back door on the left) and the kitchen behind the pass (open above the counter) |
| `fp.street` | Outside the van and kiosk: pavement and road 0.42 m below the van floor, shops across the street |
| `fp.dining` | The dining room beyond the pass (shop and up), about 9 x 13 m |
| `fp.counter` | The pizza counter: stainless body, marble top at y 0.92 (x -0.8..0.8, z -1.1..-0.46), the chilled rail of pans along the back, the sneeze guard and the ticket rail at y 1.96 |
| `fp.counter.side` | The counter on the right with the wooden cutting board (board centre 1.16, 0.94, -0.72) |
| `fp.oven.electric`, `fp.oven.gas`, `fp.oven.wood`, `fp.oven.rotary` | The oven on the right, mouth facing the player at x 1.04, centred y 1.1, z 0.2, about 0.78 x 0.62 |
| `fp.prep` | The prep station on the left: counter, tubs, sink; the prep tablet hangs on the wall at (-1.6, 1.42, -0.42) |
| `fp.crates` | A delivery stacked by the back door |
| `fp.customer.0` .. `fp.customer.5` | A customer standing, 1.75 m, facing +Z; also used seated (lowered 0.3 m) at tables |
| `fp.rider` | A delivery-app rider with helmet and insulated bag |
| `fp.table` | A dining table (top at 0.74 m) with four chairs 0.62 m out |
| `fp.pan` | One gastronorm pan (its width is set by how many the counter holds); the fill is drawn by code |
| `fp.ladle.1` .. `fp.ladle.8` | Portion ladles by size in oz, hanging from the handle (origin at the hook) |
| `fp.ticket` | A paper order ticket, 0.19 x 0.26 m, hanging from its top; the text is drawn by code |
| `fp.hand.right`, `fp.hand.left` | Forearm and hand, attached to the camera, pointing forward (-Z), fingertips at the origin |
| `fp.mouse` | A mouse running across the floor |

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
