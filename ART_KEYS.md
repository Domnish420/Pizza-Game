# Art keys

Every picture in the game is asked for by key through `Art.tex(key)` (`scripts/art.gd`).
Drop a PNG at `assets/<key with dots replaced by dashes>.png` and the game draws it instead of the
placeholder shape. No code changes. Example: key `bg.van` loads `assets/bg-van.png`.

Sizes are in game units: the front-of-house scene is 640 x 320, the bench and board are 320 x 320,
the oven is 400 x 320. Supply images at 3x those sizes or larger.

## The title screen (`scripts/title_screen.gd`)

`assets/ui/title.jpg` is the painting the game opens on: a 16:9 picture (any size; 1920 x 1080 or larger looks
sharpest), shown filling the screen with a little cropped off the edges as it drifts. The code animates on top of
it at fixed spots in the picture, in its own pixels (constants at the top of `title_screen.gd`, for the current
1024 x 572 picture): the chimney's opening `CHIMNEY` (smoke, sparks, glow), the oven's mouth `OVEN` (flicker), the
eight fairy-light bulbs `BULBS`, the sign's four corners `SIGN` (the shine, and the tap target) and the pool of light
on the cobbles `POOL`. The chalkboard menu sits over the left third, so keep that part of a new picture quiet. A new
painting with the same framing only needs those coordinates moved.

## 3D models for the first-person world (`scripts/fp/fp_world.gd`)

Every key below has a first-pass model, generated in Blender by the scripts in `tools/models/` (see
`tools/models/README.md`). They are `assets/models/fp-<key with dots as dashes>.gltf` + `.bin`, sharing the textures in
`assets/models/tex/`. To replace one, drop `assets/models/fp-<key>.glb` next to it: a `.glb` is loaded before the
`.gltf`, so yours wins with no code change. Delete the generated `.gltf` and `.bin` once you are happy with yours.

Follow the art style in `DESIGN.md` (chunky, rounded, warm colours, painted-in shadows). Shading baked into
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
| `fp.oven.electric`, `fp.oven.gas`, `fp.oven.wood`, `fp.oven.rotary` | The oven on the right, mouth facing the player at x 1.04, centred y 1.1, z 0.2, 0.78 x 0.62 (z -0.19..0.59, y 0.79..1.41). Nothing may stand in front of that rectangle: the oven view is drawn there in service. The body sits at x 0.94..1.62, z -0.29..0.83, under the hood (y 1.92). The deck ovens are cabinets on a stand with a handle bar, a temperature dial and knobs; the wood and rotary ovens have an arch-topped mosaic front with a stone arch, an entrance tunnel and the dome behind. Every oven is hollow: a chamber you see through the mouth, its deck's top at y 0.80 (the game lays its 400 x 320 deck map over x 1.04..1.62, z -0.27..0.67 and puts the pizzas there), and a landing shelf in front of the mouth (x 0.8..1.02, top about 0.79) where waiting pizzas sit. The deck ovens' chamber is a box (x 1.06..1.58, z -0.24..0.64). The dome ovens' is a low vault on an elliptical floor centred (1.335, 0.2), radii 0.285 front to back and 0.465 across, crown 0.71 above the deck, the floor running forward to the mouth under the entrance tunnel: the game keeps pizzas inside that ellipse (`Oven.FLOOR_C`, `FLOOR_R`), so keep the two in step. Keep the chamber's lining inside out (single-sided, seen from within, a part named `chamber`). The wood oven's lining is pale firebrick with soot painted into its vertex colours (clean over the fire and across the crown, black toward the mouth); its fire bed (ash, embers and the charred ends of logs laid along the wall) is against the left wall at about (1.33, 0.8, -0.135), and the game burns its own logs on it Leave z 0.63..0.86 beside a wood oven's mouth free above its base (y 0.6) for the log rack |
| `fp.prep` | The prep station on the left: counter (x -1.63..-1.01, z -1.1..0.2), sink, tubs, shelf; the prep tablet's screen is at (-1.6, 1.42, -0.42), 0.86 x 0.63, facing +X |
| `fp.crates` | A delivery stacked by the back door, placed at (-1.2, 0, 0.75) |
| `fp.customer.0` .. `fp.customer.5` | The customers, soft clay-toy style (`docs/people-style-reference.jpg`), facing +Z: 0 a kid in a backwards cap, big glasses and a hoodie (about 1.4 m; the game never has the kid order at the front), 1 a granny in a floral cardigan and pink skirt, 2 a young woman with a high ponytail, gold hoops and a mint sweater, 3 a teen with purple hair, a beanie and a varsity jacket, 4 a tall businessman in a brown suit, 5 a big-bellied papa with a moustache, braces and checked trousers. Adults are about 1.85-2.05 m with their faces at about 1.6 m. Joints the game animates: `neck` (the head and everything on it), `shoulder_l` / `shoulder_r` with `elbow_l` / `elbow_r` below (the forearm and the four-finger hand), `hip_l` / `hip_r` with `knee_l` / `knee_r`. Rotating a joint about X swings that part forward (negative) or back. Seated, the hips and knees bend 90 degrees and the figure is lowered (or raised) until its hips are at seat height (0.53 m) |
| `fp.staff.marco`, `fp.staff.luca` | The crew at Bella Napoli, built like the customers (same joints): Marco the boss, a big-bellied chef in a white double-breasted jacket, red neckerchief and cuffs, a tall toque, a big moustache, checked trousers and a rolling pin in his right hand; Luca the junior, curly ginger hair under a folded paper hat, a striped tee and a flour-dusted apron, rolled jeans. The game stands Marco out past the pass at (2.15, 0, -1.95) while you are his pizzaiolo, and Luca at the end of the prep counter at (-1.02, 0, 0.38) once you are senior; they face you and their heads follow you |
| `fp.oven_door.steel`, `fp.oven_door.iron` | The doors that shut the oven's mouth between services, placed like the ovens (scene coordinates, over the mouth y 0.79..1.41, z -0.19..0.59, facing -X): a deck oven's brushed stainless door with a smoked window, a handle bar and drop-down hinges; a dome oven's riveted black iron plate with rounded top corners, two wooden handles, a thermometer dial and an air vent |
| `fp.rider` | The delivery-app rider, built like a customer: a red cycle helmet with a chin strap, a yellow quilted puffer jacket, a green backpack whose straps run over the shoulders, down the chest and back under the arms (with a chest strap), rolled jeans, red sneakers and a phone in the right hand |
| `fp.table` | A dining table (top surface at 0.765 m; plates go at x ±0.17) with four chairs 0.62 m out, facing it |
| `fp.pan` | One gastronorm pan, 0.1 m wide x 0.2 deep, rim at y +0.03. The game stretches its width to fit the slot; the fill is drawn by code |
| `fp.ladle.1` .. `fp.ladle.8` | Portion ladles by size in oz, hanging from the hook at the origin (placed on the ladle rail at y 1.3), bowl at the bottom facing +Z |
| `fp.ticket` | A paper order ticket, 0.19 x 0.26 m, centred on its origin and facing +Z; the text and the colour bars are drawn by code just in front of it |
| `fp.hand.right`, `fp.hand.left` | A chunky cartoon hand, just the hand (no forearm or sleeve: arms got in the way of the work), the wrist rounded off, palm down, attached to the camera, pointing forward (-Z), fingertips at the origin |
| `fp.hand.right.pinch`, `fp.hand.left.pinch`, `fp.hand.right.grip`, `fp.hand.left.grip` | The same hands posed: finger and thumb pinched together (holding a topping), and a fist round a handle (the ladle, the peel). The game shows whichever fits what you hold |
| `fp.mouse` | A mouse running across the floor |
| `fp.pass` | The heated pass shelf behind the cutting board where finished pizzas go out (tap target), at (1.5, 0.92, -1.02) |
| `fp.bin` | The scraps bin at the left end of the counter, at (-0.62, 0.92, -0.78) |
| `fp.sheeter` | A tabletop dough sheeter (only with the sheeter upgrade), at (-0.62, 0.92, -0.45) |
| `fp.peel` | The launching peel: a perforated aluminium blade 0.33 m square with a rounded front, its centre at the origin and its top at y 0.004, the neck and a long oak handle running back toward you along -X to x -1.1. The game scales it to the pizza riding on it and puts your right hand on the handle as far back as is still in view |
| `fp.peel.turning` | The turning peel: a round perforated blade 0.2 m across centred at the origin, a thin aluminium shaft back along -X to x -1.2 with an oak grip on its end. The game holds it at the edge of the pizza you are turning |
| `fp.logs` | Logs in a rack beside a wood oven's mouth, on its base, at (1.19, 0.6, 0.745); keep it within 0.22 m deep (z) |
| `fp.fridge` | Upright fridge against the back wall, door facing -Z, door front at local z -0.35 (placed at -0.62, 0, 0.97) |
| `fp.thermometer` | The fridge thermometer on the door, face toward -Z (placed at -0.45, 1.45, 0.62) |
| `fp.freezer` | Chest freezer (only when the premises has one), at (1.3, 0, 1.08) |
| `fp.drystore` | Dry store shelving with flour sacks, tins and jars (placed at 0.42, 0, 1.08) |
| `fp.mop`, `fp.spray`, `fp.trapbox` | Mop and bucket, spray bottle, box of traps |
| `fp.boxes` | A wall shelf of pizza boxes, at (1.32, 1.8, -1.0). The two stacks are nodes named `flat` and `folded`, each with its origin at its base: the game scales them up and down with stock |
| `fp.mixer`, `fp.bowl` | The dough mixer (any mixer upgrade) or the mixing bowl, on the prep counter at (-1.38, 0.92, -1.0), front toward +X |
| `fp.dough_trays` | Stacked see-through proving trays with dough balls in each, a clear lid on top, at (1.47, 0.92, -0.38) |
| `fp.clipboard`, `fp.sign` | The checklist clipboard and the sign at the hatch that tells the customers OPEN / OPEN AT 11:30 / CLOSED (the text is drawn by code 4 cm in front of the sign) |
| `fp.timeclock` | The clock you clock in and out on, on the wall above the hatch (the pass in a restaurant) at 0, 2.11, -1.087, facing +Z, its back on the wall at z 0 and the dial's centre at the origin, about 26 cm across. The game turns the parts named `hand_h` and `hand_m` about their own origins (the dial's centre; they point to 12 at rest), so keep those names and pivots |

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
