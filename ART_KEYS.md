# Art keys

Every picture in the game is asked for by key through `Art.tex(key)` (`scripts/art.gd`).
Drop a PNG at `assets/<key with dots replaced by dashes>.png` and the game draws it instead of the
placeholder shape. No code changes. Example: key `bg.van` loads `assets/bg-van.png`.

Sizes are in game units: the front-of-house scene is 640 x 320, the bench and board are 320 x 320,
the oven is 400 x 320. Supply images at 3x those sizes or larger.

## Front of house (`scripts/front_scene.gd`)

| Key | Size | What it is |
| --- | --- | --- |
| `bg.van` | 640x320 | Street scene, van on the left with its hatch facing right at about (232,170). Customers queue to the right along y=228 and wait for food along y=292 |
| `bg.kiosk` | 640x320 | Covered market, kiosk on the left, same layout as the van |
| `bg.shop` | 640x320 | Room from above: the pass along the left wall (x < 54), door bottom right, tables placed by code in x 195-625, y 22-257 |
| `bg.pizzeria`, `bg.restaurant`, `bg.flagship` | 640x320 | Same layout as the shop, bigger and smarter rooms |
| `customer.0` .. `customer.5` | 30x52 | A standing customer, front view, six looks |
| `seated.0` .. `seated.5` | 18x18 | A seated guest seen from above, six looks |
| `table.clean`, `table.food`, `table.dirty` | 44x34 | A table from above: laid, with pizzas on it, with dirty plates |
| `bubble.order`, `bubble.food`, `bubble.seat`, `bubble.bill`, `bubble.clear` | 30x30 | The marker over anyone (or any table) that needs you |

## Kitchen bench and cutting board (`scripts/bench.gd`, `scripts/pizza_draw.gd`)

| Key | Size | What it is |
| --- | --- | --- |
| `bench.bg` | 320x320 | Floured steel prep bench, top-down |
| `board.bg` | 320x320 | Wooden cutting board, top-down |
| `pan` | 220x220 | Round deep pizza pan, top-down (deep-pan and gluten-free bases) |
| `pin` | 150x26 | Rolling pin, top-down, horizontal |
| `top.<id>` | 24x24 | One piece of a topping, top-down. Ids: parmesan, gorgonzola, ricotta, pecorino, goatcheese, burrata, taleggio, pepperoni, ham, prosciutto, salami, spicysalami, sausage, nduja, pancetta, guanciale, chicken, meatball, speck, mortadella, anchovy, tuna, prawn, seafood, salmon, mushroom, porcini, pepper, onion, olive, artichoke, rocket, spinach, cherrytom, sundried, aubergine, courgette, sweetcorn, pineapple, chilli, jalapeno, garlic, potato, friarielli, caper, truffle, basil, oregano, rosemary, honey, pistachio |
| `dough.blob` | 180x180 | A ball of dough, for the kneading step |

The base, sauce, cheese, browning and cuts are drawn by code because they change shape as you work.
See `PizzaDraw.draw()`; each layer is a separate block and can be swapped for shaders or textures one at a time.

## Oven (`scripts/oven_view.gd`)

| Key | Size | What it is |
| --- | --- | --- |
| `oven.electric`, `oven.gas`, `oven.wood`, `oven.rotary` | 400x320 | Looking into the oven from the front: the deck, with the landing shelf along the bottom (y > 256). Wood and rotary ovens have the fire on the left at about (58,129) |
| `oven.fire` | 80x120 | The flame. It is scaled by how hot the fire is |

Pizza spots on the deck are laid out by code (`Oven._init`).

## Icons (`scripts/kit.gd`)

| Key | Size | What it is |
| --- | --- | --- |
| `icon.<id>` | 22x22 | Ingredient icon in the supplier catalogue and stock lists. All 69 ids are in `data/ingredients.json` |

## Sound (`scripts/art.gd`)

`assets/sfx/ding.wav` (new order), `cash.wav` (paid), `bad.wav` (customer left), `tap.wav`, `up.wav` (level up, dough done).
